import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapUtils {
  /// Create a custom car marker icon with rotation
  static Future<BitmapDescriptor> createCarMarker({
    double bearing = 0,
    Color color = Colors.blue,
  }) async {
    const size = Size(80, 80);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Draw car body (simplified car shape)
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    // Car body (rectangle with rounded corners)
    final carRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(15, 20, 50, 30),
      const Radius.circular(8),
    );
    canvas.drawRRect(carRect, paint);
    canvas.drawRRect(carRect, strokePaint);
    
    // Car windows
    final windowPaint = Paint()
      ..color = Colors.blue.shade900
      ..style = PaintingStyle.fill;
    
    // Front window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, 25, 15, 10),
        const Radius.circular(4),
      ),
      windowPaint,
    );
    
    // Back window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(45, 25, 15, 10),
        const Radius.circular(4),
      ),
      windowPaint,
    );
    
    // Wheels
    final wheelPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(const Offset(25, 50), 5, wheelPaint);
    canvas.drawCircle(const Offset(55, 50), 5, wheelPaint);
    
    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    
    return BitmapDescriptor.fromBytes(uint8List);
  }

  /// Create a simple rotating car icon using a built-in approach
  static BitmapDescriptor getCarIcon({double bearing = 0}) {
    // Use a default marker with custom color for now
    // In production, you'd want to use a custom icon asset
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
  }

  /// Create destination marker
  static BitmapDescriptor getDestinationIcon() {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  /// Create start marker
  static BitmapDescriptor getStartIcon() {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  }
}

