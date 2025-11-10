import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/trips_provider.dart';

class ActiveTripScreen extends StatefulWidget {
  final String tripId;

  const ActiveTripScreen({super.key, required this.tripId});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  GoogleMapController? _mapController;
  Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  LatLng? _currentLocation;
  LatLng? _destination;
  bool _isTracking = false;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _loadTrip();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    setState(() {
      _hasLocationPermission = permissionGranted == PermissionStatus.granted;
    });
  }

  Future<void> _loadTrip() async {
    final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
    await tripsProvider.loadTrip(widget.tripId);
    
    final trip = tripsProvider.activeTrip;
    if (trip != null && trip['endLocation'] != null) {
      setState(() {
        _destination = LatLng(
          trip['endLocation']['lat']?.toDouble() ?? 0,
          trip['endLocation']['lng']?.toDouble() ?? 0,
        );
      });
    }
  }

  void _startTracking() {
    if (!_hasLocationPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission required')),
      );
      return;
    }

    setState(() {
      _isTracking = true;
    });

    _locationSubscription = _location.onLocationChanged.listen((LocationData locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
        });

        final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
        tripsProvider.updateLocation(
          widget.tripId,
          locationData.latitude!,
          locationData.longitude!,
        );

        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentLocation!),
        );
      }
    });
  }

  void _stopTracking() {
    _locationSubscription?.cancel();
    setState(() {
      _isTracking = false;
    });
  }

  Future<void> _openNavigation() async {
    if (_currentLocation == null || _destination == null) return;

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=${_currentLocation!.latitude},${_currentLocation!.longitude}&destination=${_destination!.latitude},${_destination!.longitude}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
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
      _stopTracking();
      final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
      await tripsProvider.completeTrip(widget.tripId);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Trip'),
        actions: [
          if (_isTracking)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopTracking,
              tooltip: 'Stop Tracking',
            ),
        ],
      ),
      body: Consumer<TripsProvider>(
        builder: (context, tripsProvider, _) {
          final trip = tripsProvider.activeTrip;
          if (trip == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentLocation ?? _destination ?? const LatLng(0, 0),
                  zoom: 14,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                myLocationEnabled: _isTracking,
                myLocationButtonEnabled: _isTracking,
                markers: {
                  if (_currentLocation != null)
                    Marker(
                      markerId: const MarkerId('current'),
                      position: _currentLocation!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    ),
                  if (_destination != null)
                    Marker(
                      markerId: const MarkerId('destination'),
                      position: _destination!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    ),
                },
                polylines: {
                  if (_currentLocation != null && _destination != null)
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: [_currentLocation!, _destination!],
                      color: Colors.blue,
                      width: 3,
                    ),
                },
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Destination: ${trip['endLocation']?['address'] ?? 'Unknown'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isTracking ? null : _startTracking,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Start Tracking'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _openNavigation,
                                icon: const Icon(Icons.navigation),
                                label: const Text('Navigate'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _completeTrip,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Complete Trip'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

