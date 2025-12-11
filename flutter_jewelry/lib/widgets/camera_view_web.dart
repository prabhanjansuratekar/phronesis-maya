import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

class CameraViewWeb {
  static html.IFrameElement? _iframe;
  
  static void initializeCamera(String viewId, String jewelryType, {String side = 'left'}) {
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) {
        _iframe = html.IFrameElement()
          ..src = 'camera_ar.html?viewId=$viewId&jewelry=$jewelryType&side=$side'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'camera; microphone'; // Allow camera access in iframe
        return _iframe!;
      },
    );
  }
  
  // Request camera access explicitly (triggers permission prompt)
  static Future<void> requestCameraAccess(String viewId, String jewelryType, {String side = 'left'}) async {
    try {
      // Request camera permission first
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720}
        }
      });
      
      // Stop the stream immediately - we just needed to trigger the permission prompt
      stream.getTracks().forEach((track) => track.stop());
      
      // Now initialize the camera view
      initializeCamera(viewId, jewelryType, side: side);
    } catch (e) {
      print('Camera access error: $e');
      // Still initialize - the iframe will handle its own permission request
      initializeCamera(viewId, jewelryType, side: side);
    }
  }

  static void updateJewelry({
    required String jewelryType,
    required double scale,
    required double positionX,
    required double positionY,
    required double rotation,
    String side = 'left',
  }) {
    // Send message to iframe
    if (_iframe != null && _iframe!.contentWindow != null) {
      _iframe!.contentWindow!.postMessage({
        'type': 'updateJewelry',
        'jewelryType': jewelryType,
        'scale': scale,
        'positionX': positionX,
        'positionY': positionY,
        'rotation': rotation,
        'side': side,
      }, '*');
    }
    
    // Also send to window (for direct access)
    html.window.postMessage({
      'type': 'updateJewelry',
      'jewelryType': jewelryType,
      'scale': scale,
      'positionX': positionX,
      'positionY': positionY,
      'rotation': rotation,
      'side': side,
    }, '*');
  }
  
  // Build HtmlElementView for web
  static Widget buildHtmlElementView(String viewId) {
    return HtmlElementView(viewType: viewId);
  }
}

