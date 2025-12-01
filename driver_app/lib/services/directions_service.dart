import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';

class DirectionsService {
  static const String _apiKey = 'AIzaSyD3apWjzMf9iPAdZTSGR4ln2pU7U6Lo7_I';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  Future<RouteResult?> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      // Validate coordinates
      if (originLat == 0 || originLng == 0 || destLat == 0 || destLng == 0) {
        debugPrint('DirectionsService: Invalid coordinates - origin: ($originLat, $originLng), dest: ($destLat, $destLng)');
        return null;
      }

      final url = Uri.parse(
        '$_baseUrl?origin=$originLat,$originLng&destination=$destLat,$destLng&key=$_apiKey&alternatives=false',
      );

      debugPrint('DirectionsService: Requesting route from ($originLat, $originLng) to ($destLat, $destLng)');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('DirectionsService: Request timeout');
          throw Exception('Request timeout');
        },
      );
      
      debugPrint('DirectionsService: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;
        
        debugPrint('DirectionsService: API status: $status');
        debugPrint('DirectionsService: Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        
        if (status == 'OK' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0] as Map<String, dynamic>;
          final legs = route['legs'] as List;
          
          if (legs.isEmpty) {
            debugPrint('DirectionsService: No legs in route');
            return null;
          }
          
          final leg = legs[0] as Map<String, dynamic>;
          final overviewPolyline = route['overview_polyline'] as Map<String, dynamic>;
          final encodedPolyline = overviewPolyline['points'] as String?;
          
          if (encodedPolyline == null || encodedPolyline.isEmpty) {
            debugPrint('DirectionsService: No polyline points in route');
            return null;
          }
          
          // Decode polyline
          try {
            final points = decodePolyline(encodedPolyline);
            if (points.isEmpty) {
              debugPrint('DirectionsService: Decoded polyline is empty');
              return null;
            }
            
            final routePoints = points.map((point) => LatLng(point[0].toDouble(), point[1].toDouble())).toList();
            
            final distance = (leg['distance'] as Map<String, dynamic>)['value'] as num;
            final duration = (leg['duration'] as Map<String, dynamic>)['value'] as num;
            
            debugPrint('DirectionsService: Route decoded successfully - ${routePoints.length} points, ${distance / 1000} km, ${duration / 60} min');
            
            return RouteResult(
              points: routePoints,
              distance: distance / 1000.0, // Convert to km
              duration: duration / 60.0, // Convert to minutes
            );
          } catch (e) {
            debugPrint('DirectionsService: Error decoding polyline: $e');
            return null;
          }
        } else {
          final errorMessage = data['error_message'] as String? ?? 'Unknown error';
          debugPrint('DirectionsService: API error - Status: $status, Message: $errorMessage');
          return null;
        }
      } else {
        debugPrint('DirectionsService: HTTP error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('DirectionsService: Exception getting route: $e');
      debugPrint('DirectionsService: Stack trace: $stackTrace');
      return null;
    }
  }
}

class RouteResult {
  final List<LatLng> points;
  final double distance;
  final double duration;

  RouteResult({
    required this.points,
    required this.distance,
    required this.duration,
  });
}

