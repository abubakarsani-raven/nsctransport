import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';

class GeocodingService {
  static const String _apiKey = 'AIzaSyD3apWjzMf9iPAdZTSGR4ln2pU7U6Lo7_I';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  /// Geocode an address string to coordinates
  Future<LatLng?> geocodeAddress(String address) async {
    try {
      if (address.isEmpty) {
        debugPrint('GeocodingService: Address is empty');
        return null;
      }

      final url = Uri.parse(
        '$_baseUrl?address=${Uri.encodeComponent(address)}&key=$_apiKey',
      );

      debugPrint('GeocodingService: Geocoding address: $address');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('GeocodingService: Request timeout');
          throw Exception('Request timeout');
        },
      );
      
      debugPrint('GeocodingService: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;
        
        debugPrint('GeocodingService: API status: $status');
        
        if (status == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
          final result = (data['results'] as List)[0] as Map<String, dynamic>;
          final geometry = result['geometry'] as Map<String, dynamic>?;
          
          if (geometry != null) {
            final location = geometry['location'] as Map<String, dynamic>?;
            if (location != null) {
              final lat = location['lat'] as num?;
              final lng = location['lng'] as num?;
              
              if (lat != null && lng != null) {
                final coordinates = LatLng(lat.toDouble(), lng.toDouble());
                debugPrint('GeocodingService: Geocoded to (${coordinates.latitude}, ${coordinates.longitude})');
                return coordinates;
              }
            }
          }
        } else {
          final errorMessage = data['error_message'] as String? ?? 'Unknown error';
          debugPrint('GeocodingService: API error - Status: $status, Message: $errorMessage');
          return null;
        }
      } else {
        debugPrint('GeocodingService: HTTP error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('GeocodingService: Exception geocoding address: $e');
      debugPrint('GeocodingService: Stack trace: $stackTrace');
      return null;
    }
    
    return null;
  }

  /// Reverse geocode coordinates to an address
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?latlng=$lat,$lng&key=$_apiKey',
      );

      debugPrint('GeocodingService: Reverse geocoding ($lat, $lng)');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('GeocodingService: Request timeout');
          throw Exception('Request timeout');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;
        
        if (status == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
          final result = (data['results'] as List)[0] as Map<String, dynamic>;
          final formattedAddress = result['formatted_address'] as String?;
          
          if (formattedAddress != null) {
            debugPrint('GeocodingService: Reverse geocoded to: $formattedAddress');
            return formattedAddress;
          }
        }
      }
    } catch (e) {
      debugPrint('GeocodingService: Exception reverse geocoding: $e');
    }
    
    return null;
  }
}



