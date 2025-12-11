import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart';

// Conditional imports - web uses web implementation, mobile uses native
import 'camera_view_web.dart' if (dart.library.io) 'camera_view_android_stub.dart' as web_impl;
import 'camera_view_native.dart' if (dart.library.html) 'camera_view_web_stub.dart' as native_impl;

class CameraView extends StatefulWidget {
  final String jewelryType;
  final double scale;
  final double positionX;
  final double positionY;
  final double rotation;
  final String side;
  final CameraLensDirection cameraDirection;

  const CameraView({
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
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  final String viewId = 'camera-view-${DateTime.now().millisecondsSinceEpoch}';
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void didUpdateWidget(CameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jewelryType != widget.jewelryType ||
        oldWidget.scale != widget.scale ||
        oldWidget.positionX != widget.positionX ||
        oldWidget.positionY != widget.positionY ||
        oldWidget.rotation != widget.rotation ||
        oldWidget.side != widget.side) {
      _updateJewelry();
    }
  }

  void _initializeCamera() {
    if (kIsWeb) {
      // Don't auto-initialize on web - wait for user to click "Enable Camera" button
      // This ensures the permission prompt appears
      setState(() {
        isInitialized = false; // Show permission prompt overlay
      });
    } else {
      setState(() {
        isInitialized = true;
      });
    }
  }

  void _updateJewelry() {
    if (kIsWeb) {
      web_impl.CameraViewWeb.updateJewelry(
        jewelryType: widget.jewelryType,
        scale: widget.scale,
        positionX: widget.positionX,
        positionY: widget.positionY,
        rotation: widget.rotation,
        side: widget.side,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (!isInitialized) {
        // Show camera permission prompt overlay for web
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt, size: 64, color: Colors.white),
                const SizedBox(height: 24),
                const Text(
                  'Camera Access Required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please allow camera access when prompted',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Trigger camera access request
                    await web_impl.CameraViewWeb.requestCameraAccess(viewId, widget.jewelryType, side: widget.side);
                    setState(() {
                      isInitialized = true;
                    });
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Enable Camera'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      
      // Camera is initialized, show the camera view
      // HtmlElementView is only available on web, so we use a conditional import
      return Container(
        color: Colors.black,
        child: web_impl.CameraViewWeb.buildHtmlElementView(viewId),
      );
    } else {
      // Native implementation
      if (!isInitialized) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Colors.amber,
                ),
                SizedBox(height: 20),
                Text(
                  'Loading camera...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      }
      
      return native_impl.CameraViewNative(
        jewelryType: widget.jewelryType,
        scale: widget.scale,
        positionX: widget.positionX,
        positionY: widget.positionY,
        rotation: widget.rotation,
        side: widget.side,
        cameraDirection: widget.cameraDirection,
      );
    }
  }
}
