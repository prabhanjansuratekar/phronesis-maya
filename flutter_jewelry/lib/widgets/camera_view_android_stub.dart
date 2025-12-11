// Stub file for Android - prevents import errors on mobile
import 'package:flutter/material.dart';

class CameraViewWeb {
  static void initializeCamera(String viewId, String jewelryType, {String side = 'left'}) {}
  static Future<void> requestCameraAccess(String viewId, String jewelryType, {String side = 'left'}) async {}
  static void updateJewelry({
    required String jewelryType,
    required double scale,
    required double positionX,
    required double positionY,
    required double rotation,
    String side = 'left',
  }) {}
  static Widget buildHtmlElementView(String viewId) {
    return const SizedBox.shrink();
  }
}

