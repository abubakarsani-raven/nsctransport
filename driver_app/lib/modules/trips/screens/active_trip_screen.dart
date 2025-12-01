import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/trips_provider.dart';
import '../../../providers/trip_tracking_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/location_utils.dart';
import '../../../utils/map_utils.dart';
import '../../../services/directions_service.dart';
import '../../../services/geocoding_service.dart';
import '../../../services/eta_service.dart';

class ActiveTripScreen extends StatefulWidget {
  final String tripId;

  const ActiveTripScreen({super.key, required this.tripId});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  LatLng? _destination;
  LatLng? _startLocation;
  bool _isOnline = true;
  final Connectivity _connectivity = Connectivity();
  BitmapDescriptor? _carIcon;
  bool _trafficEnabled = true;
  bool _isNavigating = false;
  List<LatLng>? _navigationRoute;
  bool _isLoadingRoute = false;
  String? _mapError;
  double? _estimatedRouteDistance; // Estimated distance from planned route (km)
  double? _estimatedFuelLitres; // Estimated fuel for planned route (L)
  
  // ETA and progress tracking
  final EtaService _etaService = EtaService();
  EtaResult? _etaResult;
  double? _progressPercentage; // 0.0 to 1.0
  Timer? _etaUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
    _loadTrip();
    _checkConnectivity();
    _initializeLocation();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    });
  }

  Future<void> _initializeLocation() async {
    // Request permissions and get current location when screen loads
    if (!mounted) return;
    
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final hasPermission = await locationProvider.checkAndRequestPermissions();
    if (hasPermission && mounted) {
      // Get current location once to populate the provider
      // This will trigger the Consumer to rebuild and show the location on map
      try {
        await locationProvider.getCurrentLocation();
        // Location will be displayed via the Consumer widget when map is created
      } catch (e) {
        debugPrint('Error getting initial location: $e');
      }
    }
  }

  Future<void> _loadCarIcon() async {
    try {
      final icon = await MapUtils.createCarMarker(
        bearing: 0,
        color: AppTheme.primaryColor,
      );
      setState(() {
        _carIcon = icon;
      });
    } catch (e) {
      // Fallback to default icon
      _carIcon = MapUtils.getCarIcon();
    }
  }

  Future<void> _loadTrip() async {
    final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
    final tripTrackingProvider = Provider.of<TripTrackingProvider>(context, listen: false);
    
    // Always reset tracking provider when loading a trip to prevent stale data
    // This ensures we don't show incorrect distance from previous trips
    if (tripTrackingProvider.isTracking) {
      if (tripTrackingProvider.activeTripId != widget.tripId) {
        // Different trip, stop tracking
        debugPrint('ActiveTripScreen: Stopping tracking for different trip (${tripTrackingProvider.activeTripId} -> ${widget.tripId})');
        await tripTrackingProvider.stopTrip();
      } else {
        // Same trip but we're reloading - ensure distance is reset
        debugPrint('ActiveTripScreen: Reloading same trip, ensuring distance is reset');
        // Force reset by stopping and the distance will be reset when we start again
        await tripTrackingProvider.stopTrip();
      }
    } else {
      // Not tracking, but check if there's residual distance data
      if (tripTrackingProvider.distance > 0) {
        debugPrint('ActiveTripScreen: WARNING - Found residual distance (${tripTrackingProvider.distance} km) when not tracking. This should be 0.');
        // Force reset by calling stopTrip which should clear everything
        await tripTrackingProvider.stopTrip();
      }
    }
    
    // Reset estimated distance and clear any existing route
    // This prevents showing a route from a previous trip or incorrect coordinates
    setState(() {
      _estimatedRouteDistance = null;
      _navigationRoute = null; // Clear route when loading new trip
    });
    
    await tripsProvider.loadTrip(widget.tripId);
    
    final trip = tripsProvider.activeTrip;
    if (trip != null) {
      debugPrint('ActiveTripScreen: Loading trip data: ${trip.keys.toList()}');
      debugPrint('ActiveTripScreen: endLocation: ${trip['endLocation']}');
      debugPrint('ActiveTripScreen: startLocation: ${trip['startLocation']}');
      
      // Parse destination coordinates
      if (trip['endLocation'] != null) {
        final endLocation = trip['endLocation'];
        double? lat;
        double? lng;
        String? address;
        
        // Handle different data structures
        if (endLocation is Map<String, dynamic>) {
          debugPrint('ActiveTripScreen: Raw endLocation data: $endLocation');
          debugPrint('ActiveTripScreen: endLocation keys: ${endLocation.keys.toList()}');
          
          // Try to parse lat/lng from various field names
          final latValue = endLocation['lat'] ?? 
                          endLocation['latitude'] ??
                          (endLocation['coordinates'] != null && endLocation['coordinates'] is List && (endLocation['coordinates'] as List).length >= 2 
                            ? (endLocation['coordinates'] as List)[1] 
                            : null);
          
          final lngValue = endLocation['lng'] ?? 
                          endLocation['longitude'] ??
                          (endLocation['coordinates'] != null && endLocation['coordinates'] is List && (endLocation['coordinates'] as List).length >= 2 
                            ? (endLocation['coordinates'] as List)[0] 
                            : null);
          
          // Get address
          address = endLocation['address'] as String? ?? 
                   endLocation['formattedAddress'] as String?;
          
          debugPrint('ActiveTripScreen: Destination source:');
          debugPrint('  - lat from endLocation[\'lat\']: ${endLocation['lat']}');
          debugPrint('  - lat from endLocation[\'latitude\']: ${endLocation['latitude']}');
          debugPrint('  - lng from endLocation[\'lng\']: ${endLocation['lng']}');
          debugPrint('  - lng from endLocation[\'longitude\']: ${endLocation['longitude']}');
          if (endLocation['coordinates'] != null) {
            debugPrint('  - coordinates: ${endLocation['coordinates']}');
          }
          
          // Convert to double (handles both string and numeric values)
          if (latValue != null) {
            lat = latValue is num ? latValue.toDouble() : (latValue is String ? double.tryParse(latValue) : null);
          }
          if (lngValue != null) {
            lng = lngValue is num ? lngValue.toDouble() : (lngValue is String ? double.tryParse(lngValue) : null);
          }
        }
        
        debugPrint('ActiveTripScreen: Parsed destination - lat: $lat, lng: $lng, address: $address');
        
        // Check if we have valid coordinates
        final hasValidCoordinates = lat != null && lng != null && 
            lat >= -90 && lat <= 90 && 
            lng >= -180 && lng <= 180 &&
            !(lat == 0 && lng == 0); // Reject (0,0) as it's likely invalid
        
        if (hasValidCoordinates) {
          // Use the coordinates directly
          setState(() {
            _destination = LatLng(lat!, lng!);
          });
          debugPrint('ActiveTripScreen: Destination set to ($lat, $lng)');
        } else if (address != null && address.isNotEmpty) {
          // Coordinates are missing or invalid, but we have an address - geocode it
          debugPrint('ActiveTripScreen: Coordinates invalid/missing, geocoding address: $address');
          _geocodeDestination(address);
        } else {
          debugPrint('ActiveTripScreen: Invalid destination - no coordinates and no address');
        }
      } else {
        debugPrint('ActiveTripScreen: endLocation is null in trip data');
      }
      
      // Parse start location coordinates
      if (trip['startLocation'] != null) {
        final startLocation = trip['startLocation'] as Map<String, dynamic>?;
        if (startLocation != null) {
          debugPrint('ActiveTripScreen: Raw startLocation data: $startLocation');
          debugPrint('ActiveTripScreen: startLocation keys: ${startLocation.keys.toList()}');
          
          // Try to get coordinates from various possible fields
          double? lat = startLocation['lat']?.toDouble() ?? 
                       startLocation['latitude']?.toDouble() ??
                       (startLocation['coordinates'] != null && startLocation['coordinates'] is List && (startLocation['coordinates'] as List).length >= 2 
                          ? (startLocation['coordinates'] as List)[1]?.toDouble() 
                          : null);
          
          double? lng = startLocation['lng']?.toDouble() ?? 
                       startLocation['longitude']?.toDouble() ??
                       (startLocation['coordinates'] != null && startLocation['coordinates'] is List && (startLocation['coordinates'] as List).length >= 2 
                          ? (startLocation['coordinates'] as List)[0]?.toDouble() 
                          : null);
          
          debugPrint('ActiveTripScreen: Parsed start location - lat: $lat, lng: $lng');
          debugPrint('ActiveTripScreen: Start location source:');
          debugPrint('  - lat from startLocation[\'lat\']: ${startLocation['lat']}');
          debugPrint('  - lat from startLocation[\'latitude\']: ${startLocation['latitude']}');
          debugPrint('  - lng from startLocation[\'lng\']: ${startLocation['lng']}');
          debugPrint('  - lng from startLocation[\'longitude\']: ${startLocation['longitude']}');
          if (startLocation['coordinates'] != null) {
            debugPrint('  - coordinates: ${startLocation['coordinates']}');
          }
          
          if (lat != null && lng != null && 
              lat >= -90 && lat <= 90 && 
              lng >= -180 && lng <= 180 &&
              !(lat == 0 && lng == 0)) {
            
            // Coordinates look valid; set start location directly
            setState(() {
              _startLocation = LatLng(lat, lng);
            });
            debugPrint('ActiveTripScreen: Start location set to ($lat, $lng)');
          } else {
            debugPrint('ActiveTripScreen: Invalid start location coordinates: lat=$lat, lng=$lng');
          }
        } else {
          debugPrint('ActiveTripScreen: startLocation is null or not a Map');
        }
      } else {
        debugPrint('ActiveTripScreen: trip[\'startLocation\'] is null');
      }
      
      // DO NOT load estimated distance on trip load - only when Start or Navigate is pressed
      // Just show markers for start and end positions
      debugPrint('ActiveTripScreen: Showing markers only - distance calculation will happen when Start/Navigate is pressed');
      
      // Clear any existing route
      setState(() {
        _estimatedRouteDistance = null;
        _navigationRoute = null;
      });
    } else {
      debugPrint('ActiveTripScreen: Trip data is null');
    }
  }
  
  /// Load estimated distance from planned route (start to destination)
  /// This provides an accurate distance before tracking starts
  Future<void> _loadEstimatedDistance() async {
    if (_startLocation == null || _destination == null) {
      return;
    }
    
    final startLat = _startLocation!.latitude;
    final startLng = _startLocation!.longitude;
    final destLat = _destination!.latitude;
    final destLng = _destination!.longitude;
    
    debugPrint('ActiveTripScreen: Loading estimated distance');
    debugPrint('ActiveTripScreen: Start location - lat: $startLat, lng: $startLng');
    debugPrint('ActiveTripScreen: Destination - lat: $destLat, lng: $destLng');
    
    // Check if coordinates might be swapped (lat/lng reversed)
    if (startLat.abs() > 90 || startLng.abs() > 180) {
      debugPrint('ActiveTripScreen: ERROR - Start location coordinates are out of valid range!');
      debugPrint('ActiveTripScreen: Coordinates might be swapped. Lat should be -90 to 90, Lng should be -180 to 180');
    }
    
    if (destLat.abs() > 90 || destLng.abs() > 180) {
      debugPrint('ActiveTripScreen: ERROR - Destination coordinates are out of valid range!');
      debugPrint('ActiveTripScreen: Coordinates might be swapped. Lat should be -90 to 90, Lng should be -180 to 180');
    }
    
    try {
      final directionsService = DirectionsService();
      final route = await directionsService.getRoute(
        originLat: startLat,
        originLng: startLng,
        destLat: destLat,
        destLng: destLng,
      );
      
      if (route != null && mounted) {
        debugPrint('ActiveTripScreen: Route calculated - Distance: ${route.distance} km');
        debugPrint('ActiveTripScreen: Route has ${route.points.length} points');
        if (route.points.isNotEmpty) {
          debugPrint('ActiveTripScreen: Route starts at (${route.points.first.latitude}, ${route.points.first.longitude})');
          debugPrint('ActiveTripScreen: Route ends at (${route.points.last.latitude}, ${route.points.last.longitude})');
        }
        
        // Always store and display the route distance and polyline
        setState(() {
          _estimatedRouteDistance = route.distance;
          // Simple fuel estimate: assume 10 km per litre
          _estimatedFuelLitres = double.tryParse(
            (route.distance / 10).toStringAsFixed(2),
          );
          if (_navigationRoute == null || _navigationRoute!.isNotEmpty == false) {
            _navigationRoute = route.points;
            debugPrint('ActiveTripScreen: Route polyline will be displayed on map');
          }
        });
        debugPrint('ActiveTripScreen: Estimated distance loaded: ${route.distance} km');
        debugPrint('ActiveTripScreen: Estimated fuel (pre-start): $_estimatedFuelLitres L');
      } else {
        debugPrint('ActiveTripScreen: Failed to load estimated distance');
      }
    } catch (e) {
      debugPrint('ActiveTripScreen: Error loading estimated distance: $e');
      // Don't show error to user - this is just for display
    }
  }
  
  Future<void> _checkConnectivity() async {
    final ConnectivityResult result = await _connectivity.checkConnectivity();
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  Future<void> _geocodeDestination(String address) async {
    try {
      final geocodingService = GeocodingService();
      final coordinates = await geocodingService.geocodeAddress(address);
      
      if (coordinates != null && mounted) {
        setState(() {
          _destination = coordinates;
        });
        debugPrint('ActiveTripScreen: Destination geocoded to (${coordinates.latitude}, ${coordinates.longitude})');
        
        // Load estimated distance if start location is available
        if (_startLocation != null) {
          _loadEstimatedDistance();
        }
        
        // Update map camera to show destination if it's not already visible
        if (_mapController != null) {
          // Wait a bit for the map to be ready
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted && _mapController != null) {
            // Fit bounds to show both current location (if available) and destination
            final locationProvider = Provider.of<LocationProvider>(context, listen: false);
            final currentLoc = locationProvider.currentLocation;
            
            if (currentLoc != null && 
                currentLoc.lat >= -90 && currentLoc.lat <= 90 && 
                currentLoc.lng >= -180 && currentLoc.lng <= 180 &&
                !(currentLoc.lat == 0 && currentLoc.lng == 0)) {
              // Show both locations
              final bounds = LatLngBounds(
                southwest: LatLng(
                  currentLoc.lat < coordinates.latitude ? currentLoc.lat : coordinates.latitude,
                  currentLoc.lng < coordinates.longitude ? currentLoc.lng : coordinates.longitude,
                ),
                northeast: LatLng(
                  currentLoc.lat > coordinates.latitude ? currentLoc.lat : coordinates.latitude,
                  currentLoc.lng > coordinates.longitude ? currentLoc.lng : coordinates.longitude,
                ),
              );
              _mapController!.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, 100.0),
              );
            } else {
              // Only show destination
              _mapController!.animateCamera(
                CameraUpdate.newLatLngZoom(coordinates, 14.0),
              );
            }
          }
        }
      } else {
        debugPrint('ActiveTripScreen: Failed to geocode destination address');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to geocode destination address. Please check your internet connection.'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('ActiveTripScreen: Error geocoding destination: $e');
      if (mounted) {
        final errorMsg = e.toString().contains('network') || 
                        e.toString().contains('connectivity') ||
                        e.toString().contains('timeout') ||
                        e.toString().contains('hostname')
            ? 'Network error: Cannot geocode address. Please check your internet connection.'
            : 'Error geocoding destination: ${e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _startTracking() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final tripTrackingProvider = Provider.of<TripTrackingProvider>(context, listen: false);
    final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
    final trip = tripsProvider.activeTrip;
    
    // Check location permissions
    final hasPermission = await locationProvider.checkAndRequestPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission required')),
        );
      }
      return;
    }

    // Use office location (startLocation from trip) as the start point
    if (trip == null || _startLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip start location not available')),
        );
      }
      return;
    }

    // Check if destination is available
    if (_destination == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Destination not available')),
        );
      }
      return;
    }

    // Ensure estimated route distance is loaded before starting tracking
    // This ensures we have the correct distance to display and validate against
    if (_estimatedRouteDistance == null || _estimatedRouteDistance == 0) {
      await _loadEstimatedDistance();
    }
    
    // Ensure tracking is stopped and reset before starting
    if (tripTrackingProvider.isTracking) {
      debugPrint('ActiveTripScreen: Stopping existing tracking before starting new trip');
      await tripTrackingProvider.stopTrip();
      // Wait a bit to ensure cleanup completes
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Verify distance is zero before starting
    if (tripTrackingProvider.distance > 0) {
      debugPrint('ActiveTripScreen: WARNING - Distance is not zero before starting: ${tripTrackingProvider.distance} km');
      debugPrint('ActiveTripScreen: Force resetting tracking provider');
      await tripTrackingProvider.stopTrip();
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    debugPrint('ActiveTripScreen: Starting trip tracking - Distance before start: ${tripTrackingProvider.distance} km');
    
    // Start trip tracking with office location as start point
    // This resets the tracking provider distance to 0.0
    final started = await tripTrackingProvider.startTrip(
      widget.tripId,
      startLat: _startLocation!.latitude,
      startLng: _startLocation!.longitude,
    );

    // Verify that tracking distance is reset (should be 0.0)
    if (started) {
      debugPrint('ActiveTripScreen: Trip tracking started - Distance after start: ${tripTrackingProvider.distance} km');
      if (tripTrackingProvider.distance > 0) {
        debugPrint('ActiveTripScreen: ERROR - Tracking distance is not zero after start: ${tripTrackingProvider.distance} km');
        debugPrint('ActiveTripScreen: This indicates a bug in the tracking provider reset logic');
      }
    } else {
      debugPrint('ActiveTripScreen: Failed to start trip tracking');
    }

    // Start location tracking
    await locationProvider.startTracking(tripId: widget.tripId);

    // Start API trip
    await tripsProvider.startTrip(widget.tripId);
    
    // Load and display the planned route from DirectionsService when tracking starts
    // This ensures the user sees the correct route following roads, not a straight line
    // This also updates _estimatedRouteDistance if it wasn't already loaded
    await _loadPlannedRouteForTracking();
    
    // Start ETA updates
    _startEtaUpdates();
  }
  
  /// Start periodic ETA updates
  void _startEtaUpdates() {
    _etaUpdateTimer?.cancel();
    _etaUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateETA();
    });
    // Update immediately
    _updateETA();
  }
  
  /// Update ETA calculation
  Future<void> _updateETA() async {
    final tripTrackingProvider = Provider.of<TripTrackingProvider>(context, listen: false);
    
    if (!tripTrackingProvider.isTracking || _destination == null) {
      return;
    }
    
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentLoc = locationProvider.currentLocation;
    
    if (currentLoc == null) {
      return;
    }
    
    try {
      final eta = await _etaService.calculateETA(
        currentLat: currentLoc.lat,
        currentLng: currentLoc.lng,
        destinationLat: _destination!.latitude,
        destinationLng: _destination!.longitude,
        currentSpeed: tripTrackingProvider.currentSpeed,
      );
      
      if (eta != null && mounted) {
        setState(() {
          _etaResult = eta;
        });
        
        // Calculate route progress
        if (_estimatedRouteDistance != null && _estimatedRouteDistance! > 0) {
          final traveledDistance = tripTrackingProvider.distance;
          _progressPercentage = _etaService.calculateProgress(
            totalDistance: _estimatedRouteDistance!,
            traveledDistance: traveledDistance,
          );
        } else if (eta.distance > 0) {
          // Use ETA distance as total distance
          final traveledDistance = tripTrackingProvider.distance;
          _progressPercentage = _etaService.calculateProgress(
            totalDistance: eta.distance,
            traveledDistance: traveledDistance,
          );
        }
      }
    } catch (e) {
      debugPrint('ActiveTripScreen: Error updating ETA: $e');
    }
  }
  
  /// Stop ETA updates
  void _stopEtaUpdates() {
    _etaUpdateTimer?.cancel();
    _etaUpdateTimer = null;
    setState(() {
      _etaResult = null;
      _progressPercentage = null;
    });
  }

  /// Load planned route from DirectionsService for display during tracking
  /// This shows the route following actual roads, not a straight line
  Future<void> _loadPlannedRouteForTracking() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    // NOTE: For this project, the business requirement is that the planned route
    // should always be from the MAIN OFFICE (trip startLocation) to the destination,
    // not from the driver's live GPS position. So we prioritise _startLocation.
    //
    // We still fall back to current location only if startLocation is missing/invalid,
    // to avoid completely failing in edge cases.
    var currentLoc = locationProvider.currentLocation;
    if (currentLoc == null) {
      currentLoc = await locationProvider.getCurrentLocation();
    }
    
    // Determine origin coordinates - use start location if available, otherwise use current location
    double originLat;
    double originLng;
    
    if (_startLocation != null &&
        _startLocation!.latitude >= -90 && _startLocation!.latitude <= 90 &&
        _startLocation!.longitude >= -180 && _startLocation!.longitude <= 180 &&
        !(_startLocation!.latitude == 0 && _startLocation!.longitude == 0)) {
      // Use MAIN OFFICE / trip start location
      originLat = _startLocation!.latitude;
      originLng = _startLocation!.longitude;
      debugPrint('ActiveTripScreen: Using startLocation as planned route origin: ($originLat, $originLng)');
    } else if (currentLoc != null &&
        currentLoc.lat != 0 && currentLoc.lng != 0 &&
        currentLoc.lat >= -90 && currentLoc.lat <= 90 &&
        currentLoc.lng >= -180 && currentLoc.lng <= 180) {
      // Fallback: use current location only if startLocation is unavailable
      originLat = currentLoc.lat;
      originLng = currentLoc.lng;
      debugPrint('ActiveTripScreen: WARNING - startLocation missing/invalid, falling back to current location as origin: ($originLat, $originLng)');
    } else {
      debugPrint('ActiveTripScreen: Cannot load route - no valid startLocation or current location');
      return;
    }
    
    // Validate destination
    if (_destination == null ||
        _destination!.latitude == 0 || _destination!.longitude == 0 ||
        _destination!.latitude < -90 || _destination!.latitude > 90 ||
        _destination!.longitude < -180 || _destination!.longitude > 180) {
      debugPrint('ActiveTripScreen: Cannot load route - invalid destination');
      return;
    }
    
    debugPrint('ActiveTripScreen: Loading planned route from ($originLat, $originLng) to (${_destination!.latitude}, ${_destination!.longitude})');
    
    try {
      final directionsService = DirectionsService();
      final route = await directionsService.getRoute(
        originLat: originLat,
        originLng: originLng,
        destLat: _destination!.latitude,
        destLng: _destination!.longitude,
      );
      
      if (route != null && mounted) {
        debugPrint('ActiveTripScreen: Route calculated - Distance: ${route.distance} km');
        debugPrint('ActiveTripScreen: Route has ${route.points.length} points');
        if (route.points.isNotEmpty) {
          debugPrint('ActiveTripScreen: Route starts at (${route.points.first.latitude}, ${route.points.first.longitude})');
          debugPrint('ActiveTripScreen: Route ends at (${route.points.last.latitude}, ${route.points.last.longitude})');
        }
        
        // Always show the route and store the distance, regardless of how long it is
        setState(() {
          // Store the planned route - this will show the route following roads
          _navigationRoute = route.points;
          // Store estimated distance from the route (this is the accurate distance)
          _estimatedRouteDistance = route.distance;
          // Update estimated fuel based on planned distance
          _estimatedFuelLitres = double.tryParse(
            (route.distance / 10).toStringAsFixed(2),
          );
        });
        
        // Fit bounds to show full route
        if (_mapController != null && route.points.isNotEmpty) {
          final allPoints = List<LatLng>.from(route.points);
          if (_destination != null) {
            // Ensure destination is included
            final destInRoute = allPoints.any((point) => 
              (point.latitude - _destination!.latitude).abs() < 0.0001 &&
              (point.longitude - _destination!.longitude).abs() < 0.0001
            );
            if (!destInRoute) {
              allPoints.add(_destination!);
            }
          }
          final bounds = _boundsFromLatLngList(allPoints);
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 100.0),
          );
        }
        debugPrint('ActiveTripScreen: Planned route loaded successfully - ${route.points.length} points, ${route.distance} km');
      } else {
        debugPrint('ActiveTripScreen: Failed to load planned route');
      }
    } catch (e) {
      debugPrint('ActiveTripScreen: Error loading planned route: $e');
      // Don't show error to user - route loading is non-critical for tracking
    }
  }

  void _stopTracking() {
    // Stop ETA updates
    _stopEtaUpdates();
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final tripTrackingProvider = Provider.of<TripTrackingProvider>(context, listen: false);
    
    locationProvider.stopTracking();
    tripTrackingProvider.stopTrip();
  }

  /// Open external navigation app (Google Maps or Apple Maps) for turn-by-turn directions
  Future<void> _openExternalNavigation() async {
    if (_destination == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Destination not available')),
        );
      }
      return;
    }

    final destLat = _destination!.latitude;
    final destLng = _destination!.longitude;

    // Prefer planned start location (office/pickup) as origin; fall back to current GPS
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    var currentLoc = locationProvider.currentLocation;
    if (currentLoc == null) {
      currentLoc = await locationProvider.getCurrentLocation();
    }

    final double? originLat = _startLocation?.latitude ?? currentLoc?.lat;
    final double? originLng = _startLocation?.longitude ?? currentLoc?.lng;

    if (originLat == null || originLng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current location not available')),
        );
      }
      return;
    }

    try {
      bool launched = false;

      // Always prefer a Google Maps directions URL with explicit origin + destination
      final directionsUrl =
          'https://www.google.com/maps/dir/?api=1'
          '&origin=$originLat,$originLng'
          '&destination=$destLat,$destLng'
          '&travelmode=driving';
      final directionsUri = Uri.parse(directionsUrl);

      if (await canLaunchUrl(directionsUri)) {
        await launchUrl(directionsUri, mode: LaunchMode.externalApplication);
        launched = true;
      }

      // Fallback for web/other platforms or if Google Maps URL fails
      if (!launched) {
        final webUrl =
            'https://www.google.com/maps/dir/?api=1'
            '&origin=$originLat,$originLng'
            '&destination=$destLat,$destLng'
            '&travelmode=driving';
        final webUri = Uri.parse(webUrl);
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
          launched = true;
        }
      }

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps for navigation')),
        );
      }
    } catch (e) {
      debugPrint('ActiveTripScreen: Error opening external navigation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open navigation')),
        );
      }
    }
  }

  Future<void> _openNavigation() async {
    // If not tracking yet, start tracking first (this starts the timer)
    final tripTrackingProvider = Provider.of<TripTrackingProvider>(context, listen: false);
    
    if (!tripTrackingProvider.isTracking) {
      // Start tracking first (this starts the timer)
      await _startTracking();
      // Wait a bit for tracking to initialize
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Show dialog to choose navigation method
    if (!_isNavigating && _destination != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Navigation Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.navigation, color: Colors.blue),
                title: const Text('Open in Maps App'),
                subtitle: const Text('Turn-by-turn navigation in Google Maps or Apple Maps'),
                onTap: () => Navigator.pop(context, 'external'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.map, color: Colors.green),
                title: const Text('Show Route in App'),
                subtitle: const Text('Display route on map in this app'),
                onTap: () => Navigator.pop(context, 'internal'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      
      if (choice == 'external') {
        // Open external navigation app
        await _openExternalNavigation();
        // Also load and show route in app for reference
        await _loadRouteInApp();
        return;
      } else if (choice != 'internal') {
        // User cancelled
        return;
      }
    }
    
    // Toggle navigation mode for internal route display
    if (_isNavigating) {
      setState(() {
        _isNavigating = false;
        _navigationRoute = null;
      });
      return;
    }
    
    // Load route in app
    await _loadRouteInApp();
  }

  /// Load and display route in the app
  Future<void> _loadRouteInApp() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    // For in-app navigation view, we also want the route to represent the full
    // trip from MAIN OFFICE (startLocation) to destination, not from wherever
    // the driver currently is.
    //
    // We still fall back to current location if startLocation is not available.
    var currentLoc = locationProvider.currentLocation;
    if (currentLoc == null) {
      currentLoc = await locationProvider.getCurrentLocation();
    }

    if (_destination == null ||
        _destination!.latitude == 0 || _destination!.longitude == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Destination not available. Please check trip details.')),
        );
      }
      debugPrint('ActiveTripScreen: Destination is null or invalid');
      return;
    }

    // Decide origin: prefer startLocation (office), fallback to current GPS
    double originLat;
    double originLng;

    if (_startLocation != null &&
        _startLocation!.latitude >= -90 && _startLocation!.latitude <= 90 &&
        _startLocation!.longitude >= -180 && _startLocation!.longitude <= 180 &&
        !(_startLocation!.latitude == 0 && _startLocation!.longitude == 0)) {
      originLat = _startLocation!.latitude;
      originLng = _startLocation!.longitude;
      debugPrint('ActiveTripScreen: In-app navigation origin set to startLocation: ($originLat, $originLng)');
    } else if (currentLoc != null &&
        currentLoc.lat >= -90 && currentLoc.lat <= 90 &&
        currentLoc.lng >= -180 && currentLoc.lng <= 180 &&
        !(currentLoc.lat == 0 && currentLoc.lng == 0)) {
      originLat = currentLoc.lat;
      originLng = currentLoc.lng;
      debugPrint('ActiveTripScreen: WARNING - startLocation missing/invalid, using current location as navigation origin: ($originLat, $originLng)');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to determine a valid origin for navigation.')),
        );
      }
      debugPrint('ActiveTripScreen: No valid origin (startLocation or current location) for navigation');
      return;
    }

    // Validate destination coordinates
    if (_destination!.latitude < -90 || _destination!.latitude > 90 || 
        _destination!.longitude < -180 || _destination!.longitude > 180 ||
        (_destination!.latitude == 0 && _destination!.longitude == 0)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid destination coordinates: (${_destination!.latitude}, ${_destination!.longitude})')),
        );
      }
      debugPrint('ActiveTripScreen: Invalid destination - lat: ${_destination!.latitude}, lng: ${_destination!.longitude}');
      return;
    }

    debugPrint('ActiveTripScreen: Navigating from ($originLat, $originLng) to (${_destination!.latitude}, ${_destination!.longitude})');
    
    setState(() {
      _isLoadingRoute = true;
    });
    
    try {
      final directionsService = DirectionsService();
      final route = await directionsService.getRoute(
        originLat: originLat,
        originLng: originLng,
        destLat: _destination!.latitude,
        destLng: _destination!.longitude,
      );
      
      if (route != null && mounted) {
        debugPrint('ActiveTripScreen: Route calculated for navigation - Distance: ${route.distance} km');
        
        setState(() {
          _isNavigating = true;
          _navigationRoute = route.points;
          _isLoadingRoute = false;
          // Update estimated distance & fuel if not already set or if this is more accurate
          if (_estimatedRouteDistance == null || _estimatedRouteDistance == 0) {
            _estimatedRouteDistance = route.distance;
            _estimatedFuelLitres = double.tryParse(
              (route.distance / 10).toStringAsFixed(2),
            );
          }
        });
        
        // Fit bounds to show full route (including destination)
        if (_mapController != null && route.points.isNotEmpty) {
          // Ensure destination is included in bounds
          final allPoints = List<LatLng>.from(route.points);
          if (_destination != null && 
              _destination!.latitude != 0 && 
              _destination!.longitude != 0) {
            // Check if destination is not already in the route points
            final destInRoute = allPoints.any((point) => 
              (point.latitude - _destination!.latitude).abs() < 0.0001 &&
              (point.longitude - _destination!.longitude).abs() < 0.0001
            );
            if (!destInRoute) {
              allPoints.add(_destination!);
            }
          }
          final bounds = _boundsFromLatLngList(allPoints);
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 100.0),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingRoute = false;
          });
          // Get more detailed error message
          final errorMsg = 'Unable to get route. Please check your internet connection and try again.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in _loadRouteInApp: $e');
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
        final errorMsg = e.toString().contains('network') || 
                        e.toString().contains('connectivity') ||
                        e.toString().contains('timeout') ||
                        e.toString().contains('hostname')
            ? 'Network error: Please check your internet connection and try again.'
            : 'Error getting route: ${e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _loadRouteInApp(),
            ),
          ),
        );
      }
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    if (list.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      );
    }
    
    double? minLat, maxLat, minLng, maxLng;
    for (var point in list) {
      minLat = minLat == null ? point.latitude : (point.latitude < minLat ? point.latitude : minLat);
      maxLat = maxLat == null ? point.latitude : (point.latitude > maxLat ? point.latitude : maxLat);
      minLng = minLng == null ? point.longitude : (point.longitude < minLng ? point.longitude : minLng);
      maxLng = maxLng == null ? point.longitude : (point.longitude > maxLng ? point.longitude : maxLng);
    }
    return LatLngBounds(
      southwest: LatLng(minLat ?? 0, minLng ?? 0),
      northeast: LatLng(maxLat ?? 0, maxLng ?? 0),
    );
  }

  Future<void> _completeTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Trip'),
        content: const Text('Are you sure you want to mark this trip as complete?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Stop tracking first
        _stopTracking();
        
        // Complete trip on backend
        final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
        await tripsProvider.completeTrip(widget.tripId);
        
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip completed successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Navigate back to dashboard
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('Error completing trip: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to complete trip: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _showVehicleAndPassengerDetails() {
    final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
    final trip = tripsProvider.activeTrip;
    
    if (trip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip data not available')),
      );
      return;
    }
    
    // Safely extract request data - it might be a Map (populated) or String (just ID)
    final request = trip['requestId'];
    final requestData = request is Map<String, dynamic> ? request : null;
    
    // Safely extract vehicle data
    // Try trip['vehicleId'] first, then request['assignedVehicleId']
    final vehicle = trip['vehicleId'];
    final vehicleFromRequest = requestData?['assignedVehicleId'];
    final vehicleData = (vehicle is Map<String, dynamic> ? vehicle : null) ??
                       (vehicleFromRequest is Map<String, dynamic> ? vehicleFromRequest : null);
    
    // Safely extract requester data
    final requester = requestData?['requesterId'];
    final requesterData = requester is Map<String, dynamic> ? requester : null;
    
    // Safely extract participants - ensure it's always a List
    final participantsRaw = requestData?['participantIds'];
    List<dynamic> participants = [];
    if (participantsRaw is List) {
      participants = participantsRaw;
    } else if (participantsRaw != null) {
      // If it's not a List but not null, wrap it in a List
      participants = [participantsRaw];
    }

    // Safely extract start (pickup office) location from trip
    final startLocation = trip['startLocation'];
    Map<String, dynamic>? startLocationData;
    if (startLocation is Map<String, dynamic>) {
      startLocationData = startLocation;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildVehicleAndPassengerSheet(
        vehicleData: vehicleData,
        requesterData: requesterData,
        participants: participants,
        startLocationData: startLocationData,
      ),
    );
  }

  Widget _buildVehicleAndPassengerSheet({
    required Map<String, dynamic>? vehicleData,
    required Map<String, dynamic>? requesterData,
    required List<dynamic> participants,
    required Map<String, dynamic>? startLocationData,
  }) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Trip Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pickup Office Section
                  if (startLocationData != null) ...[
                    _buildDetailsSection(
                      context,
                      'Pickup Office',
                      Icons.location_city,
                      [
                        if (startLocationData['name'] != null)
                          _buildDetailRow(
                            'Office',
                            startLocationData['name'],
                            Icons.business,
                          ),
                        if (startLocationData['address'] != null)
                          _buildDetailRow(
                            'Address',
                            startLocationData['address'],
                            Icons.place,
                          ),
                        if (startLocationData['lat'] != null &&
                            startLocationData['lng'] != null)
                          _buildDetailRow(
                            'Coordinates',
                            '${startLocationData['lat']}, ${startLocationData['lng']}',
                            Icons.my_location,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Vehicle Section
                  if (vehicleData != null)
                    _buildDetailsSection(
                      context,
                      'Vehicle Information',
                      Icons.directions_car,
                      [
                        if (vehicleData['make'] != null)
                          _buildDetailRow('Make', vehicleData['make'], Icons.branding_watermark),
                        if (vehicleData['model'] != null)
                          _buildDetailRow('Model', vehicleData['model'], Icons.category),
                        if (vehicleData['plateNumber'] != null)
                          _buildDetailRow('Plate Number', vehicleData['plateNumber'], Icons.confirmation_number),
                        if (vehicleData['capacity'] != null)
                          _buildDetailRow('Capacity', '${vehicleData['capacity']} passengers', Icons.people),
                        if (vehicleData['year'] != null)
                          _buildDetailRow('Year', vehicleData['year'].toString(), Icons.calendar_today),
                      ],
                    ),
                  
                  // Requester Section
                  if (requesterData != null) ...[
                    const SizedBox(height: 20),
                    _buildDetailsSection(
                      context,
                      'Requester Information',
                      Icons.person,
                      [
                        if (requesterData['name'] != null)
                          _buildDetailRow('Name', requesterData['name'], Icons.person),
                        if (requesterData['email'] != null)
                          _buildContactDetailRow(
                            'Email',
                            requesterData['email'],
                            Icons.email,
                            () => _launchEmail(requesterData['email']),
                          ),
                        if (requesterData['phone'] != null)
                          _buildContactDetailRow(
                            'Phone',
                            requesterData['phone'],
                            Icons.phone,
                            () => _launchPhone(requesterData['phone']),
                          ),
                        if (requesterData['department'] != null)
                          _buildDetailRow('Department', requesterData['department'], Icons.business),
                      ],
                    ),
                  ],
                  
                  // Participants Section
                  if (participants.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildDetailsSection(
                      context,
                      'Participants (${participants.length})',
                      Icons.people,
                      participants.asMap().entries.expand<Widget>((entry) {
                        final index = entry.key;
                        final participant = entry.value;
                        if (participant is Map<String, dynamic>) {
                          return [
                            if (participant['name'] != null)
                              _buildDetailRow('Name', participant['name'], Icons.person),
                            if (participant['email'] != null)
                              _buildContactDetailRow(
                                'Email',
                                participant['email'],
                                Icons.email,
                                () => _launchEmail(participant['email']),
                              ),
                            if (participant['phone'] != null)
                              _buildContactDetailRow(
                                'Phone',
                                participant['phone'],
                                Icons.phone,
                                () => _launchPhone(participant['phone']),
                              ),
                            if (participant['department'] != null)
                              _buildDetailRow('Department', participant['department'], Icons.business),
                            if (index < participants.length - 1)
                              const Divider(height: 24),
                          ];
                        }
                        return [];
                      }).toList(),
                    ),
                  ],
                  
                  // Show message if no data available
                  if (vehicleData == null && requesterData == null && participants.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No vehicle or passenger details available',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactDetailRow(String label, String value, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            value,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                        ),
                        const Icon(Icons.open_in_new, size: 16, color: AppTheme.primaryColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open email: $email')),
        );
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot make call: $phone')),
        );
      }
    }
  }

  @override
  void dispose() {
    _etaUpdateTimer?.cancel();
    _connectivitySubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Active Trip'),
        actions: [
          // Vehicle and Passenger Details Button
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showVehicleAndPassengerDetails,
            tooltip: 'Vehicle & Passenger Details',
          ),
          // Stop Tracking Button
          Consumer<TripTrackingProvider>(
            builder: (context, trackingProvider, _) {
              if (!trackingProvider.isTracking) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _stopTracking,
                tooltip: 'Stop Tracking',
              );
            },
          ),
        ],
      ),
      body: Consumer<TripsProvider>(
        builder: (context, tripsProvider, _) {
          final trip = tripsProvider.activeTrip;
          if (trip == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Consumer2<LocationProvider, TripTrackingProvider>(
            builder: (context, locationProvider, trackingProvider, _) {
              final currentLoc = locationProvider.currentLocation;
              final route = trackingProvider.route;
              
              // Update route points for polyline - convert LocationPoint to LatLng
              final routeLatLngs = route.map((point) => LatLng(point.lat, point.lng)).toList();
              
              // Determine initial camera position - prioritize current location
              LatLng initialTarget = const LatLng(0, 0);
              double initialZoom = 14.0;
              
              if (currentLoc != null) {
                // Use actual current location if available
                initialTarget = LatLng(currentLoc.lat, currentLoc.lng);
                initialZoom = trackingProvider.isTracking ? 17.0 : 15.0;
              } else if (_startLocation != null && _destination != null) {
                // Fit bounds to show start location and destination
                final bounds = LatLngBounds(
                  southwest: LatLng(
                    _startLocation!.latitude < _destination!.latitude 
                        ? _startLocation!.latitude 
                        : _destination!.latitude,
                    _startLocation!.longitude < _destination!.longitude 
                        ? _startLocation!.longitude 
                        : _destination!.longitude,
                  ),
                  northeast: LatLng(
                    _startLocation!.latitude > _destination!.latitude 
                        ? _startLocation!.latitude 
                        : _destination!.latitude,
                    _startLocation!.longitude > _destination!.longitude 
                        ? _startLocation!.longitude 
                        : _destination!.longitude,
                  ),
                );
                // Calculate center and zoom
                final centerLat = (bounds.southwest.latitude + bounds.northeast.latitude) / 2;
                final centerLng = (bounds.southwest.longitude + bounds.northeast.longitude) / 2;
                initialTarget = LatLng(centerLat, centerLng);
                initialZoom = 13.0; // Zoom level to show both markers
              } else if (_startLocation != null) {
                // Fallback to start location (office)
                initialTarget = _startLocation!;
                initialZoom = 14.0;
              } else if (_destination != null) {
                // Fallback to destination
                initialTarget = _destination!;
                initialZoom = 14.0;
              }
              
              // Update camera based on tracking state (skip if navigating to avoid conflicts)
              if (_mapController != null && !_isNavigating) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (trackingProvider.isTracking && currentLoc != null) {
                    // When tracking: follow current location with bearing and 3D street view
                    final bearing = locationProvider.currentBearing ?? 0;
                    _mapController?.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(currentLoc.lat, currentLoc.lng),
                          bearing: bearing,
                          tilt: 45.0, // 3D street view tilt (45 degrees for nice perspective)
                          zoom: 18.0, // Closer zoom for better 3D street view experience
                        ),
                      ),
                    );
                  } else if (currentLoc != null && _destination != null) {
                    // When not tracking: fit bounds to show driver location and destination only (no start location)
                    final bounds = LatLngBounds(
                      southwest: LatLng(
                        currentLoc.lat < _destination!.latitude 
                            ? currentLoc.lat 
                            : _destination!.latitude,
                        currentLoc.lng < _destination!.longitude 
                            ? currentLoc.lng 
                            : _destination!.longitude,
                      ),
                      northeast: LatLng(
                        currentLoc.lat > _destination!.latitude 
                            ? currentLoc.lat 
                            : _destination!.latitude,
                        currentLoc.lng > _destination!.longitude 
                            ? currentLoc.lng 
                            : _destination!.longitude,
                      ),
                    );
                    // Calculate center point manually
                    final centerLat = (bounds.southwest.latitude + bounds.northeast.latitude) / 2;
                    final centerLng = (bounds.southwest.longitude + bounds.northeast.longitude) / 2;
                    _mapController?.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(centerLat, centerLng),
                          zoom: _calculateZoomLevel(bounds),
                          tilt: 0.0, // Flat view for overview
                          bearing: 0.0,
                        ),
                      ),
                    );
                  } else if (currentLoc != null) {
                    // Only current location available
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(currentLoc.lat, currentLoc.lng),
                        15.0,
                      ),
                    );
                  }
                });
              }
              // When tracking starts while navigating, clear navigation
              if (trackingProvider.isTracking && _isNavigating) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _isNavigating = false;
                    _navigationRoute = null;
                  });
                });
              }

              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: initialTarget,
                      zoom: initialZoom,
                      tilt: trackingProvider.isTracking ? 45.0 : 0.0, // 3D street view when tracking (45 degrees for nice perspective)
                      bearing: trackingProvider.isTracking && locationProvider.currentBearing != null 
                          ? locationProvider.currentBearing! 
                          : 0.0, // Rotate map based on driving direction when tracking
                    ),
                    onMapCreated: (controller) async {
                      _mapController = controller;
                      
                      // Clear any previous map errors
                      if (mounted) {
                        setState(() {
                          _mapError = null;
                        });
                      }
                      
                      // Check connectivity before proceeding
                      if (!_isOnline && mounted) {
                        setState(() {
                          _mapError = 'Maps require internet connection. Please check your network and try again.';
                        });
                      }
                      
                      // Wait a bit for location to be available
                      await Future.delayed(const Duration(milliseconds: 800));
                      
                      // Get current location
                      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
                      var loc = locationProvider.currentLocation;
                      
                      // If location not in provider yet, try to get it
                      if (loc == null || (loc.lat == 0 && loc.lng == 0)) {
                        loc = await locationProvider.getCurrentLocation();
                      }
                      
                      // Fit bounds to show device location and destination
                      if (loc != null && 
                          loc.lat >= -90 && loc.lat <= 90 && 
                          loc.lng >= -180 && loc.lng <= 180 &&
                          !(loc.lat == 0 && loc.lng == 0) &&
                          _destination != null && 
                          _destination!.latitude >= -90 && 
                          _destination!.latitude <= 90 &&
                          _destination!.longitude >= -180 && 
                          _destination!.longitude <= 180 &&
                          !(_destination!.latitude == 0 && _destination!.longitude == 0)) {
                        // Show both device location and destination
                        final bounds = LatLngBounds(
                          southwest: LatLng(
                            loc.lat < _destination!.latitude ? loc.lat : _destination!.latitude,
                            loc.lng < _destination!.longitude ? loc.lng : _destination!.longitude,
                          ),
                          northeast: LatLng(
                            loc.lat > _destination!.latitude ? loc.lat : _destination!.latitude,
                            loc.lng > _destination!.longitude ? loc.lng : _destination!.longitude,
                          ),
                        );
                        controller.animateCamera(
                          CameraUpdate.newLatLngBounds(bounds, 100.0), // 100px padding
                        );
                      } else if (loc != null && 
                                 loc.lat >= -90 && loc.lat <= 90 && 
                                 loc.lng >= -180 && loc.lng <= 180 &&
                                 !(loc.lat == 0 && loc.lng == 0)) {
                        // Only device location available
                        controller.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(loc.lat, loc.lng),
                            15.0,
                          ),
                        );
                      } else if (_destination != null && 
                                 _destination!.latitude >= -90 && 
                                 _destination!.latitude <= 90 &&
                                 _destination!.longitude >= -180 && 
                                 _destination!.longitude <= 180 &&
                                 !(_destination!.latitude == 0 && _destination!.longitude == 0)) {
                        // Only destination available
                        controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_destination!, 14.0),
                        );
                      }
                    },
                    mapType: MapType.normal,
                    trafficEnabled: _trafficEnabled,
                    myLocationEnabled: false, // Disabled - we use custom marker to avoid duplicate location markers
                    myLocationButtonEnabled: false, // Disabled - we have custom locate button
                    compassEnabled: true,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: true, // Enable 3D street view gestures (pinch to tilt)
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    buildingsEnabled: true, // Enable 3D buildings for better street view
                    mapToolbarEnabled: false, // Disable default toolbar to keep UI clean
                    // IMPORTANT: Only 2 markers - Driver Location and Destination
                    markers: _buildMarkers(currentLoc, locationProvider, trackingProvider, trip),
                    onCameraMoveStarted: () {
                      // Clear map errors when user interacts with map
                      if (_mapError != null && mounted) {
                        setState(() {
                          _mapError = null;
                        });
                      }
                    },
                    polylines: {
                      // Planned route from DirectionsService (when available)
                      // ALWAYS show this when available - it follows actual roads
                      if (_navigationRoute != null && _navigationRoute!.isNotEmpty)
                        Polyline(
                          polylineId: const PolylineId('planned_route'),
                          points: _navigationRoute!,
                          color: trackingProvider.isTracking
                              ? Colors.green
                              : (_isNavigating ? Colors.blue : Colors.blue),
                          width: 6,
                          patterns: [],
                          zIndex: 1,
                        ),
                      // Actual GPS tracking route (only show when tracking and we have enough points)
                      if (trackingProvider.isTracking &&
                          routeLatLngs.length > 3 &&
                          _navigationRoute != null &&
                          _navigationRoute!.isNotEmpty)
                        Polyline(
                          polylineId: const PolylineId('tracked_route'),
                          points: routeLatLngs,
                          color: AppTheme.primaryColor.withOpacity(0.5),
                          width: 3,
                          patterns: [PatternItem.dash(15), PatternItem.gap(8)],
                          zIndex: 0,
                        ),
                    },
                  ),
              // Traffic toggle button
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'traffic_button',
                  onPressed: () {
                    setState(() {
                      _trafficEnabled = !_trafficEnabled;
                    });
                  },
                  backgroundColor: _trafficEnabled 
                      ? AppTheme.primaryColor 
                      : Colors.grey,
                  child: Icon(
                    _trafficEnabled ? Icons.traffic : Icons.traffic_outlined,
                    color: Colors.white,
                  ),
                  tooltip: _trafficEnabled ? 'Hide Traffic' : 'Show Traffic',
                ),
              ),
              // Locate Me button
              Positioned(
                top: 80,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'locate_me_button',
                  onPressed: () async {
                    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
                    final loc = await locationProvider.getCurrentLocation();
                    if (loc != null && _mapController != null && mounted) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(loc.lat, loc.lng),
                          15.0,
                        ),
                      );
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Unable to get current location')),
                        );
                      }
                    }
                  },
                  backgroundColor: AppTheme.primaryColor,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                  ),
                  tooltip: 'Locate Me',
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isOnline)
                      Card(
                        color: AppTheme.warningColor,
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_off, color: Colors.white),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'No Internet Connection',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Maps require internet connection. Please check your network settings.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_mapError != null)
                      Card(
                        color: Colors.orange.shade700,
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.white),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Map Loading Error',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _mapError!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _mapError = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Destination row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Destination',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        trip['endLocation']?['address'] ?? 'Unknown',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Primary metrics row (ETA & Remaining) when available
                            if (_etaResult != null && trackingProvider.isTracking) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildMetric(
                                    context,
                                    'ETA',
                                    _etaResult!.formattedDuration,
                                    Icons.access_time,
                                    Colors.blue,
                                  ),
                                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                                  _buildMetric(
                                    context,
                                    'Remaining',
                                    _etaResult!.formattedDistance,
                                    Icons.navigation,
                                    Colors.orange,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            // Secondary metrics row (Distance, Est. Fuel, Duration)
                            Row(
                              children: [
                                _buildMetric(
                                  context,
                                  'Distance',
                                  _getDistanceDisplay(trackingProvider),
                                  Icons.straighten,
                                  AppTheme.primaryColor,
                                ),
                                Container(width: 1, height: 40, color: Colors.grey.shade300),
                                _buildMetric(
                                  context,
                                  'Est. Fuel',
                                  _getEstimatedFuelDisplay(),
                                  Icons.local_gas_station,
                                  Colors.redAccent,
                                ),
                                Container(width: 1, height: 40, color: Colors.grey.shade300),
                                _buildMetric(
                                  context,
                                  'Duration',
                                  trackingProvider.isTracking
                                      ? _formatDuration(trackingProvider.duration)
                                      : '0m',
                                  Icons.timer,
                                  Colors.green,
                                ),
                              ],
                            ),
                            // Route progress bar
                            if (_progressPercentage != null && trackingProvider.isTracking) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _progressPercentage!.clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _progressPercentage! > 0.9
                                        ? Colors.green
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(_progressPercentage! * 100).toStringAsFixed(0)}% complete',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: trackingProvider.isTracking ? null : _startTracking,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Start'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoadingRoute ? null : _openNavigation,
                                    icon: _isLoadingRoute
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(_isNavigating ? Icons.close : Icons.navigation),
                                    label: Text(_isNavigating ? 'Stop Nav' : 'Navigate'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          _isNavigating ? Colors.grey : Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _completeTrip,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Complete Trip',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Get distance display string based on tracking state
  /// Shows estimated distance before tracking, tracked distance during tracking
  /// Always shows estimated route distance until tracked distance becomes meaningful
  String _getDistanceDisplay(TripTrackingProvider trackingProvider) {
    // If we have estimated route distance, prefer it unless tracked distance is meaningful
    if (_estimatedRouteDistance != null && _estimatedRouteDistance! > 0) {
      // If tracking is active and we have tracked distance
      if (trackingProvider.isTracking && trackingProvider.distance > 0) {
        // Only show tracked distance if it's reasonable (not suspiciously high)
        // Tracked distance should not exceed estimated route distance by more than 50%
        // This prevents showing incorrect GPS noise accumulation
        final maxReasonableDistance = _estimatedRouteDistance! * 1.5;
        
        if (trackingProvider.distance <= maxReasonableDistance) {
          // Tracked distance is reasonable, show it
          return LocationUtils.formatDistance(trackingProvider.distance);
        } else {
          // Tracked distance is suspiciously high (likely GPS noise), show estimated route distance
          debugPrint('ActiveTripScreen: Tracked distance (${trackingProvider.distance} km) exceeds reasonable limit (${maxReasonableDistance} km), showing estimated route distance (${_estimatedRouteDistance} km)');
          return LocationUtils.formatDistance(_estimatedRouteDistance!);
        }
      } else {
        // Not tracking or no tracked distance yet, show estimated route distance
        return LocationUtils.formatDistance(_estimatedRouteDistance!);
      }
    }
    
    // If no estimated route distance available but tracking is active
    if (trackingProvider.isTracking && trackingProvider.distance > 0) {
      return LocationUtils.formatDistance(trackingProvider.distance);
    }
    
    // Fallback to 0 if no distance available
    return '0 m';
  }
  
  String _getEstimatedFuelDisplay() {
    if (_estimatedFuelLitres != null && _estimatedFuelLitres! > 0) {
      return '${_estimatedFuelLitres!.toStringAsFixed(2)} L';
    }
    return '--';
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Build markers set - Show Start Location, Driver Location, and Destination
  Set<Marker> _buildMarkers(
    dynamic currentLoc, // LocationPoint? from LocationProvider
    LocationProvider locationProvider,
    TripTrackingProvider trackingProvider,
    Map<String, dynamic> trip,
  ) {
    final Set<Marker> markers = {};
    
    // Marker 1: Start Location (Office) - Green marker
    if (_startLocation != null && 
        _startLocation!.latitude >= -90 && 
        _startLocation!.latitude <= 90 &&
        _startLocation!.longitude >= -180 && 
        _startLocation!.longitude <= 180 &&
        !(_startLocation!.latitude == 0 && _startLocation!.longitude == 0)) {
      markers.add(
        Marker(
          markerId: const MarkerId('start_location'),
          position: _startLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Start Location',
            snippet: trip['startLocation']?['address'] ?? 
                    trip['startLocation']?['formattedAddress'] ?? 
                    '${_startLocation!.latitude}, ${_startLocation!.longitude}',
          ),
        ),
      );
    }
    
    // Marker 2: Driver/Current Location - only show while tracking, with subtle styling
    if (trackingProvider.isTracking &&
        currentLoc != null &&
        currentLoc.lat != null &&
        currentLoc.lng != null &&
        currentLoc.lat >= -90 &&
        currentLoc.lat <= 90 &&
        currentLoc.lng >= -180 &&
        currentLoc.lng <= 180 &&
        !(currentLoc.lat == 0 && currentLoc.lng == 0)) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: LatLng(currentLoc.lat, currentLoc.lng),
          icon: _carIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          rotation: locationProvider.currentBearing ?? 0,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          infoWindow: const InfoWindow(title: 'Your location'),
        ),
      );
    }
    
    // Marker 3: Destination (Red pin)
    if (_destination != null && 
        _destination!.latitude >= -90 && 
        _destination!.latitude <= 90 &&
        _destination!.longitude >= -180 && 
        _destination!.longitude <= 180 &&
        !(_destination!.latitude == 0 && _destination!.longitude == 0)) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination!,
          icon: MapUtils.getDestinationIcon(),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: trip['endLocation']?['address'] ?? 
                    trip['endLocation']?['formattedAddress'] ?? 
                    '${_destination!.latitude}, ${_destination!.longitude}',
          ),
        ),
      );
    }
    
    return markers;
  }

  /// Calculate appropriate zoom level for bounds
  double _calculateZoomLevel(LatLngBounds bounds) {
    // Simple zoom calculation based on bounds size
    final latDiff = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngDiff = bounds.northeast.longitude - bounds.southwest.longitude;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    
    if (maxDiff > 0.1) return 10.0;
    if (maxDiff > 0.05) return 11.0;
    if (maxDiff > 0.01) return 13.0;
    if (maxDiff > 0.005) return 14.0;
    return 15.0;
  }
}

