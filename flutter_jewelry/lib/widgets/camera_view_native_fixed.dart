import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraViewNative extends StatefulWidget {
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
  State<CameraViewNative> createState() => _CameraViewNativeState();
}

class _CameraViewNativeState extends State<CameraViewNative> {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  bool _isInitialized = false;
  bool _hasPermission = false;
  String? _errorMessage;
  Face? _detectedFace;
  Size? _imageSize;
  List<CameraDescription> _cameras = [];
  CameraLensDirection _currentCameraDirection = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    _currentCameraDirection = widget.cameraDirection;
    _initializeCamera();
  }

  @override
  void didUpdateWidget(CameraViewNative oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraDirection != widget.cameraDirection) {
      _currentCameraDirection = widget.cameraDirection;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _switchCamera();
      });
    }
  }

  @override
  void dispose() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _errorMessage = 'Camera permission denied';
        });
        return;
      }

      setState(() {
        _hasPermission = true;
      });

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras available';
        });
        return;
      }

      // Use selected camera direction
      final selectedCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == _currentCameraDirection,
        orElse: () => _cameras.first,
      );

      // Initialize face detector
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: true,
          enableTracking: true,
          minFaceSize: 0.1,
        ),
      );

      // Initialize camera controller
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _imageSize = Size(
            _controller!.value.previewSize?.height ?? 0,
            _controller!.value.previewSize?.width ?? 0,
          );
        });

        // Start face detection (temporarily disabled)
        _startFaceDetection();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    try {
      await _controller?.stopImageStream();
    } catch (e) {
      debugPrint('Error stopping image stream: $e');
    }
    
    try {
      await _controller?.dispose();
    } catch (e) {
      debugPrint('Error disposing camera: $e');
    }

    // Use widget's camera direction
    _currentCameraDirection = widget.cameraDirection;

    // Find the new camera
    final newCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == _currentCameraDirection,
      orElse: () => _cameras.first,
    );

    // Initialize new camera
    _controller = CameraController(
      newCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _imageSize = Size(
          _controller!.value.previewSize?.height ?? 0,
          _controller!.value.previewSize?.width ?? 0,
        );
      });
      _startFaceDetection();
    }
  }

  void _startFaceDetection() {
    // Temporarily disabled to avoid YUV errors
    // Will re-enable after fixing conversion
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'Camera permission required',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }

    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Camera preview
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.previewSize?.height ?? screenSize.width,
              height: _controller!.value.previewSize?.width ?? screenSize.height,
              child: CameraPreview(_controller!),
            ),
          ),
        ),
        
        // Jewelry overlay - ALWAYS VISIBLE, VERY PROMINENT
        Positioned(
          left: screenSize.width / 2 - 150, // Centered
          top: screenSize.height / 2 - 150, // Centered
          child: IgnorePointer(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: widget.jewelryType == 'earring' 
                    ? Colors.amber.withValues(alpha: 1.0) // Fully opaque
                    : const Color(0xFFD4AF37).withValues(alpha: 1.0), // Gold, fully opaque
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow, width: 6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.yellow.withValues(alpha: 1.0),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.jewelryType == 'earring' 
                          ? Icons.diamond 
                          : Icons.ring_volume,
                      color: Colors.white,
                      size: 200, // HUGE
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.jewelryType.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 15,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Status indicator
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _detectedFace != null ? Colors.green : Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _detectedFace != null ? 'Face Detected' : 'Camera Ready',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        // Camera switch button
        Positioned(
          top: 20,
          right: 20,
          child: IconButton(
            icon: Icon(
              _currentCameraDirection == CameraLensDirection.front
                  ? Icons.camera_rear
                  : Icons.camera_front,
              color: Colors.white,
              size: 28,
            ),
            onPressed: _cameras.length > 1 ? _switchCamera : null,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.7),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }
}

