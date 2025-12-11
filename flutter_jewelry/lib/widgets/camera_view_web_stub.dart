// Stub file for web - prevents import errors on Android
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

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

// Stub for CameraViewNative on web
class CameraViewNative extends StatelessWidget {
  final String jewelryType;
  final double scale;
  final double positionX;
  final double positionY;
  final double rotation;
  final String side;
  final CameraLensDirection cameraDirection;

  const CameraViewNative({
    super.key,
    required this.jewelryType,
    required this.scale,
    required this.positionX,
    required this.positionY,
    required this.rotation,
    this.side = 'left',
    this.cameraDirection = CameraLensDirection.front,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text('Native camera not available on web', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
