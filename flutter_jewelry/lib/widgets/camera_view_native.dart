import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../services/mediapipe_face_mesh.dart';
import 'package:path_provider/path_provider.dart';

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
  
  // MediaPipe Face Mesh support
  bool _useMediaPipe = false;
  bool _mediaPipeInitialized = false;
  List<Map<String, double>>? _mediaPipeLandmarks;
  
  // Interactive positioning, scaling, and rotation
  Offset _jewelryPosition = Offset.zero;
  Offset _trackedPosition = Offset.zero; // Position from face/hand tracking
  bool _isManuallyPositioned = false; // Track if user manually moved the jewelry
  double _jewelryScale = 1.0; // Start larger for better visibility
  double _baseScale = 1.0;
  double _rotationAngle = 0.0;
  double _baseRotation = 0.0;
  Offset _lastPanPosition = Offset.zero;
  static const double _baseSize = 150.0; // Smaller base size
  static const double _minScale = 0.05; // Much smaller minimum scale
  static const double _maxScale = 5.0; // Larger maximum scale
  Timer? _detectionTimer;
  bool _isDetecting = false;
  // Track per-ear visibility recency to hide when ear not visible
  final Map<String, DateTime> _earLastSeen = {
    'left': DateTime.fromMillisecondsSinceEpoch(0),
    'right': DateTime.fromMillisecondsSinceEpoch(0),
  };
  static const int _earHideThresholdMs = 700; // hide ear after 0.7s of not seeing it

  @override
  void initState() {
    super.initState();
    _currentCameraDirection = widget.cameraDirection;
    // Initialize jewelry position to center of screen (will be set in build)
    _initializeMediaPipe();
    _initializeCamera();
    _preloadAssets();
  }
  
  // Preload asset paths once - not needed for ModelViewer, it handles assets directly
  Future<void> _preloadAssets() async {
    // ModelViewer on Android serves assets through its own HTTP server
    // No need to copy files to temp directory
    debugPrint('Assets will be served by ModelViewer HTTP server');
  }
  
  Future<void> _initializeMediaPipe() async {
    if (Platform.isAndroid) {
      try {
        debugPrint('Initializing MediaPipe Face Mesh...');
        _mediaPipeInitialized = await MediaPipeFaceMesh.initialize();
        if (_mediaPipeInitialized) {
          setState(() {
            _useMediaPipe = true;
          });
          debugPrint('MediaPipe Face Mesh initialized successfully');
        } else {
          debugPrint('MediaPipe initialization failed, falling back to ML Kit');
          _useMediaPipe = false;
          _mediaPipeInitialized = false;
        }
      } catch (e, stackTrace) {
        debugPrint('MediaPipe initialization error: $e');
        debugPrint('Stack trace: $stackTrace');
        _useMediaPipe = false;
        _mediaPipeInitialized = false;
      }
    }
  }

  @override
  void didUpdateWidget(CameraViewNative oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraDirection != widget.cameraDirection) {
      _currentCameraDirection = widget.cameraDirection;
      // Use a post-frame callback to ensure state is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _switchCamera();
      });
    }
    // Reset position and scale when jewelry type changes
    if (oldWidget.jewelryType != widget.jewelryType) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final screenSize = MediaQuery.of(context).size;
          setState(() {
            _jewelryPosition = Offset(
              screenSize.width / 2,
              screenSize.height / 2,
            );
            _jewelryScale = 0.6; // Reset to smaller default
            _baseScale = 0.6;
            _rotationAngle = 0.0;
            _baseRotation = 0.0;
          });
        }
      });
    }
  }

  @override
  void dispose() async {
    _detectionTimer?.cancel();
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _faceDetector?.close();
    if (_useMediaPipe) {
      await MediaPipeFaceMesh.dispose();
    }
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

      // Initialize face detector with improved options for better landmark detection
      // Lower minFaceSize for better detection, especially for selfie camera
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: true,
          enableContours: true, // Enable contours for better landmark detection
          enableTracking: true,
          minFaceSize: 0.1, // Lower minimum face size for better detection (was 0.15)
          performanceMode: FaceDetectorMode.fast, // Use fast mode for better real-time performance
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

        // Start face detection
        _startFaceDetection();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return; // Need at least 2 cameras to switch

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

    // Use widget's camera direction (not toggle)  
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
        _imageSize = Size(
          _controller!.value.previewSize?.height ?? 0,
          _controller!.value.previewSize?.width ?? 0,
        );
      });
      _startFaceDetection();
    }
  }

  void _startFaceDetection() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    // Start face detection with throttling to avoid performance issues
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_controller != null && _controller!.value.isStreamingImages) {
        // Process frames periodically
      }
    });
    
    _controller!.startImageStream((CameraImage image) {
      if (!_isDetecting) {
        _isDetecting = true;
        _detectFaces(image).then((_) {
          _isDetecting = false;
        });
      }
    });
  }

  Future<void> _detectFaces(CameraImage image) async {
    // Try MediaPipe first if available
    if (_useMediaPipe && _mediaPipeInitialized) {
      try {
        final landmarks = await MediaPipeFaceMesh.processImage(image);
        if (landmarks != null && landmarks.length >= 468) {
          if (mounted) {
            setState(() {
              _mediaPipeLandmarks = landmarks;
              _detectedFace = null; // We'll use MediaPipe landmarks directly
              
              // Update tracked position using MediaPipe landmarks
              if (!_isManuallyPositioned && mounted) {
                try {
                  final screenSize = MediaQuery.of(context).size;
                  final newPosition = _getJewelryPositionFromMediaPipe(screenSize);
                  if (newPosition != null) {
                    // Smooth interpolation for tracking
                    if (_trackedPosition == Offset.zero) {
                      _trackedPosition = newPosition;
                    } else {
                      _trackedPosition = Offset(
                        _trackedPosition.dx * 0.7 + newPosition.dx * 0.3,
                        _trackedPosition.dy * 0.7 + newPosition.dy * 0.3,
                      );
                    }
                  }
                } catch (e) {
                  debugPrint('Error updating tracked position from MediaPipe: $e');
                }
              }
            });
          }
          return; // Successfully processed with MediaPipe
        }
      } catch (e) {
        debugPrint('MediaPipe detection error: $e');
        // Fall through to ML Kit
      }
    }
    
    // Fallback to ML Kit
    if (_faceDetector == null) {
      debugPrint('ML Kit: FaceDetector is null');
      return;
    }

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        debugPrint('ML Kit: Failed to create InputImage');
        return;
      }
      
      debugPrint('ML Kit: Processing image, size: ${image.width}x${image.height}');
      final faces = await _faceDetector!.processImage(inputImage);
      debugPrint('ML Kit: Detected ${faces.length} face(s)');
      
      if (mounted) {
        setState(() {
          _detectedFace = faces.isNotEmpty ? faces.first : null;
          _mediaPipeLandmarks = null; // Clear MediaPipe landmarks
          
          if (_detectedFace != null) {
            debugPrint('ML Kit: Face detected with ${_detectedFace!.landmarks.length} landmarks');
          } else {
            debugPrint('ML Kit: No face detected');
          }
          
          // Update tracked position if face detected and not manually positioned
          if (_detectedFace != null && !_isManuallyPositioned && mounted) {
            try {
              final screenSize = MediaQuery.of(context).size;
              final newPosition = _getJewelryPosition(screenSize);
              if (newPosition != null) {
                // Smooth interpolation for tracking
                if (_trackedPosition == Offset.zero) {
                  _trackedPosition = newPosition;
                } else {
                  _trackedPosition = Offset(
                    _trackedPosition.dx * 0.7 + newPosition.dx * 0.3,
                    _trackedPosition.dy * 0.7 + newPosition.dy * 0.3,
                  );
                }
              }
            } catch (e) {
              debugPrint('Error updating tracked position: $e');
            }
          } else if (_detectedFace == null) {
            // Reset manual positioning flag when face is lost
            _isManuallyPositioned = false;
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint('ML Kit face detection error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  // Get jewelry position from MediaPipe landmarks
  Offset? _getJewelryPositionFromMediaPipe(Size screenSize) {
    if (_mediaPipeLandmarks == null || _mediaPipeLandmarks!.length < 468) return null;
    if (_controller == null) return null;
    
    final previewSize = _controller!.value.previewSize;
    if (previewSize == null) return null;
    
    final displayedWidth = previewSize.height.toDouble();
    final displayedHeight = previewSize.width.toDouble();
    final imageWidth = previewSize.width.toDouble();
    final imageHeight = previewSize.height.toDouble();
    
    final displayedAspect = displayedWidth / displayedHeight;
    final screenAspect = screenSize.width / screenSize.height;
    
    double scaleFactor;
    double offsetX = 0;
    double offsetY = 0;
    
    if (displayedAspect > screenAspect) {
      scaleFactor = screenSize.height / displayedHeight;
      final scaledWidth = displayedWidth * scaleFactor;
      offsetX = (screenSize.width - scaledWidth) / 2;
    } else {
      scaleFactor = screenSize.width / displayedWidth;
      final scaledHeight = displayedHeight * scaleFactor;
      offsetY = (screenSize.height - scaledHeight) / 2;
    }
    
    final isFrontCamera = _currentCameraDirection == CameraLensDirection.front;
    
    if (widget.jewelryType == 'earring') {
      // Use MediaPipe ear landmarks
      final leftEar = MediaPipeFaceMesh.getLeftEarPosition(_mediaPipeLandmarks!);
      if (leftEar != null) {
        // MediaPipe landmarks are normalized [0, 1], convert to image coordinates
        var x = leftEar['x']! * imageWidth;
        var y = leftEar['y']! * imageHeight;
        
        // Transform coordinates
        var displayX = y;
        var displayY = imageWidth - x;
        
        if (isFrontCamera) {
          displayX = displayedWidth - displayX;
        }
        
        final screenX = (displayX * scaleFactor) + offsetX;
        final screenY = (displayY * scaleFactor) + offsetY;
        
        return Offset(screenX, screenY);
      }
    }
    
    return null;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      if (image.planes.length < 3) {
        debugPrint('InputImage: Invalid image format, expected 3 planes, got ${image.planes.length}');
        return null;
      }
      
      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];
      
      // Convert YUV420 to NV21 format (required by ML Kit)
      final ySize = image.width * image.height;
      final uvSize = (image.width * image.height / 4).round(); // UV plane is 1/4 size
      final totalSize = ySize + (uvSize * 2); // Y + UV interleaved
      
      debugPrint('InputImage: Converting YUV420 to NV21, size: ${image.width}x${image.height}');
      debugPrint('InputImage: Y plane: ${yPlane.bytes.length} bytes, bytesPerRow: ${yPlane.bytesPerRow}');
      debugPrint('InputImage: U plane: ${uPlane.bytes.length} bytes, bytesPerRow: ${uPlane.bytesPerRow}');
      debugPrint('InputImage: V plane: ${vPlane.bytes.length} bytes, bytesPerRow: ${vPlane.bytesPerRow}');
      
      // Create NV21 format buffer
      final nv21Bytes = Uint8List(totalSize);
      
      // Copy Y plane (luminance)
      final yBytes = yPlane.bytes;
      final yCopyLength = ySize < yBytes.length ? ySize : yBytes.length;
      for (int i = 0; i < yCopyLength; i++) {
        if (i < nv21Bytes.length) {
          nv21Bytes[i] = yBytes[i];
        }
      }
      
      // Interleave V and U planes (VU order for NV21)
      // NV21 format: Y plane followed by interleaved VU plane
      final uBytes = uPlane.bytes;
      final vBytes = vPlane.bytes;
      final uvPixelCount = (image.width * image.height / 4).round();
      
      for (int i = 0; i < uvPixelCount; i++) {
        final uvIndex = ySize + (i * 2);
        if (uvIndex + 1 < nv21Bytes.length && i < vBytes.length && i < uBytes.length) {
          nv21Bytes[uvIndex] = vBytes[i];     // V first
          nv21Bytes[uvIndex + 1] = uBytes[i]; // U second
        }
      }

      // Determine rotation - front camera typically needs 270deg on Android
      final imageRotation = _currentCameraDirection == CameraLensDirection.front
          ? InputImageRotation.rotation270deg
          : InputImageRotation.rotation90deg;

      final inputImageData = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: InputImageFormat.nv21,
        bytesPerRow: yPlane.bytesPerRow,
      );

      debugPrint('InputImage: Created NV21 buffer, size: ${nv21Bytes.length} bytes');
      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: inputImageData,
      );
    } catch (e, stackTrace) {
      debugPrint('Error creating InputImage: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  // Get all ear positions for earrings (both left and right)
  List<Offset> _getEarringPositions(Size screenSize) {
    // Use MediaPipe landmarks if available (more accurate)
    if (_useMediaPipe && _mediaPipeLandmarks != null && _mediaPipeLandmarks!.length >= 468) {
      return _getEarringPositionsFromMediaPipe(screenSize);
    }
    
    // Fallback to ML Kit
    if (_detectedFace == null || _controller == null) {
      debugPrint('_getEarringPositions: No face detected or controller null');
      return [];
    }

    final face = _detectedFace!;
    final landmarks = face.landmarks;
    final previewSize = _controller!.value.previewSize;
    if (previewSize == null) {
      debugPrint('_getEarringPositions: Preview size is null');
      return [];
    }
    
    debugPrint('_getEarringPositions: Face detected, calculating positions...');
    debugPrint('_getEarringPositions: Preview size: ${previewSize.width}x${previewSize.height}');
    debugPrint('_getEarringPositions: Screen size: ${screenSize.width}x${screenSize.height}');

    // Camera preview is displayed rotated 90deg, so swap dimensions
    final displayedWidth = previewSize.height.toDouble();  // 720
    final displayedHeight = previewSize.width.toDouble();  // 1280
    final imageWidth = previewSize.width.toDouble();      // 1280 (original image width)
    final imageHeight = previewSize.height.toDouble();     // 720 (original image height)
    
    debugPrint('_getEarringPositions: Displayed size: ${displayedWidth}x${displayedHeight}, Image size: ${imageWidth}x${imageHeight}');
    
    final displayedAspect = displayedWidth / displayedHeight;
    final screenAspect = screenSize.width / screenSize.height;
    
    double scaleFactor;
    double offsetX = 0;
    double offsetY = 0;
    
    if (displayedAspect > screenAspect) {
      scaleFactor = screenSize.height / displayedHeight;
      final scaledWidth = displayedWidth * scaleFactor;
      offsetX = (screenSize.width - scaledWidth) / 2;
    } else {
      scaleFactor = screenSize.width / displayedWidth;
      final scaledHeight = displayedHeight * scaleFactor;
      offsetY = (screenSize.height - scaledHeight) / 2;
    }
    
    debugPrint('_getEarringPositions: Scale factor: $scaleFactor, offsetX: $offsetX, offsetY: $offsetY');
    
    final isFrontCamera = _currentCameraDirection == CameraLensDirection.front;
    final leftEar = landmarks[FaceLandmarkType.leftEar];
    final rightEar = landmarks[FaceLandmarkType.rightEar];
    final now = DateTime.now();
    List<Offset> positions = [];
    
    // Left ear position (no fallback: hide if not visible)
    if (leftEar != null) {
      final x = leftEar.position.x.toDouble();
      final y = leftEar.position.y.toDouble();
      debugPrint('Left ear landmark: image($x, $y)');
      
      // ML Kit landmarks are returned in InputImage coordinate space
      // InputImage has rotation 270deg, so coordinates are already rotated
      // InputImage size is (width=1280, height=720), but after 270deg rotation it's effectively (720, 1280)
      // The preview displays the image rotated 90deg (portrait mode)
      
      // ML Kit returns coordinates in the rotated InputImage space
      // Since InputImage is 270deg rotated, the effective size is swapped: (720, 1280)
      // But landmarks might be in original image space (1280, 720) or rotated space
      // Let's use the InputImage metadata size directly
      
      // Use InputImage size (which accounts for rotation)
      // After 270deg rotation: original (1280, 720) becomes (720, 1280) in rotated space
      final inputImageWidth = imageHeight;  // 720 after rotation
      final inputImageHeight = imageWidth;  // 1280 after rotation
      
      // Normalize coordinates to InputImage space
      final normalizedX = (x / inputImageWidth).clamp(0.0, 1.0);
      final normalizedY = (y / inputImageHeight).clamp(0.0, 1.0);
      
      // Map to display space (preview is shown rotated 90deg, so dimensions match)
      var displayX = normalizedX * displayedWidth;   // Direct mapping
      var displayY = normalizedY * displayedHeight;  // Direct mapping
      
      if (isFrontCamera) {
        // Mirror horizontally for front camera (mirror effect)
        displayX = displayedWidth - displayX;
      }
      
      // Transform from display coordinates to screen coordinates
      final screenX = (displayX * scaleFactor) + offsetX;
      final screenY = (displayY * scaleFactor) + offsetY;
      
      debugPrint('Left ear: image($x, $y) -> screen($screenX, $screenY)');
      positions.add(Offset(screenX, screenY));
      _earLastSeen['left'] = now;
    }
    
    // Right ear position (no fallback: hide if not visible)
    if (rightEar != null) {
      final x = rightEar.position.x.toDouble();
      final y = rightEar.position.y.toDouble();
      debugPrint('Right ear landmark: image($x, $y)');
      
      // ML Kit landmarks are returned in InputImage coordinate space
      // InputImage has rotation 270deg, so coordinates are already rotated
      // InputImage size is (width=1280, height=720), but after 270deg rotation it's effectively (720, 1280)
      // The preview displays the image rotated 90deg (portrait mode)
      
      // ML Kit returns coordinates in the rotated InputImage space
      // Since InputImage is 270deg rotated, the effective size is swapped: (720, 1280)
      // But landmarks might be in original image space (1280, 720) or rotated space
      // Let's use the InputImage metadata size directly
      
      // Use InputImage size (which accounts for rotation)
      // After 270deg rotation: original (1280, 720) becomes (720, 1280) in rotated space
      final inputImageWidth = imageHeight;  // 720 after rotation
      final inputImageHeight = imageWidth;  // 1280 after rotation
      
      // Normalize coordinates to InputImage space
      final normalizedX = (x / inputImageWidth).clamp(0.0, 1.0);
      final normalizedY = (y / inputImageHeight).clamp(0.0, 1.0);
      
      // Map to display space (preview is shown rotated 90deg, so dimensions match)
      var displayX = normalizedX * displayedWidth;   // Direct mapping
      var displayY = normalizedY * displayedHeight;  // Direct mapping
      
      if (isFrontCamera) {
        // Mirror horizontally for front camera (mirror effect)
        displayX = displayedWidth - displayX;
      }
      
      // Transform from display coordinates to screen coordinates
      final screenX = (displayX * scaleFactor) + offsetX;
      final screenY = (displayY * scaleFactor) + offsetY;
      
      debugPrint('Right ear: image($x, $y) -> screen($screenX, $screenY)');
      positions.add(Offset(screenX, screenY));
      _earLastSeen['right'] = now;
    }
    
    // Filter by recency so occluded ears hide after a short timeout
    final yaw = _detectedFace?.headEulerAngleY ?? 0.0;
    final filtered = <Offset>[];
    for (final pos in positions) {
      final isLeft = pos.dx >= screenSize.width / 2;
      final last = _earLastSeen[isLeft ? 'left' : 'right']!;
      final recentlySeen = now.difference(last).inMilliseconds <= _earHideThresholdMs;
      // Yaw-based occlusion: when turning right (yaw < -20), hide left; turning left (yaw > 20), hide right.
      final occludedByYaw = (yaw > 20 && !isLeft) || (yaw < -20 && isLeft);
      if (recentlySeen && !occludedByYaw) {
        filtered.add(pos);
      }
    }

    // Remove duplicates (positions that are very close to each other)
    List<Offset> uniquePositions = [];
    for (final pos in filtered) {
      bool isDuplicate = false;
      for (final existing in uniquePositions) {
        final distance = (pos - existing).distance;
        if (distance < 10.0) { // If positions are within 10 pixels, consider duplicate
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        uniquePositions.add(pos);
      }
    }
    
    debugPrint('Total earring positions: ${filtered.length}, unique: ${uniquePositions.length}');
    return uniquePositions;
  }
  
  // Get earring positions from MediaPipe landmarks (more accurate)
  List<Offset> _getEarringPositionsFromMediaPipe(Size screenSize) {
    if (_mediaPipeLandmarks == null || _mediaPipeLandmarks!.length < 468) return [];
    if (_controller == null) return [];
    
    final previewSize = _controller!.value.previewSize;
    if (previewSize == null) return [];
    
    final displayedWidth = previewSize.height.toDouble();
    final displayedHeight = previewSize.width.toDouble();
    final imageWidth = previewSize.width.toDouble();
    final imageHeight = previewSize.height.toDouble();
    
    final displayedAspect = displayedWidth / displayedHeight;
    final screenAspect = screenSize.width / screenSize.height;
    
    double scaleFactor;
    double offsetX = 0;
    double offsetY = 0;
    
    if (displayedAspect > screenAspect) {
      scaleFactor = screenSize.height / displayedHeight;
      final scaledWidth = displayedWidth * scaleFactor;
      offsetX = (screenSize.width - scaledWidth) / 2;
    } else {
      scaleFactor = screenSize.width / displayedWidth;
      final scaledHeight = displayedHeight * scaleFactor;
      offsetY = (screenSize.height - scaledHeight) / 2;
    }
    
    final isFrontCamera = _currentCameraDirection == CameraLensDirection.front;
    List<Offset> positions = [];
    
    // Get left ear position from MediaPipe
    final leftEar = MediaPipeFaceMesh.getLeftEarPosition(_mediaPipeLandmarks!);
    if (leftEar != null) {
      // MediaPipe landmarks are normalized [0, 1], convert to image coordinates
      var x = leftEar['x']! * imageWidth;
      var y = leftEar['y']! * imageHeight;
      
      // Transform coordinates
      var displayX = y;
      var displayY = imageWidth - x;
      
      if (isFrontCamera) {
        displayX = displayedWidth - displayX;
      }
      
      final screenX = (displayX * scaleFactor) + offsetX;
      final screenY = (displayY * scaleFactor) + offsetY;
      debugPrint('MediaPipe Left ear position: screen($screenX, $screenY)');
      positions.add(Offset(screenX, screenY));
    }
    
    // Get right ear position from MediaPipe
    final rightEar = MediaPipeFaceMesh.getRightEarPosition(_mediaPipeLandmarks!);
    if (rightEar != null) {
      var x = rightEar['x']! * imageWidth;
      var y = rightEar['y']! * imageHeight;
      
      var displayX = y;
      var displayY = imageWidth - x;
      
      if (isFrontCamera) {
        displayX = displayedWidth - displayX;
      }
      
      final screenX = (displayX * scaleFactor) + offsetX;
      final screenY = (displayY * scaleFactor) + offsetY;
      debugPrint('MediaPipe Right ear position: screen($screenX, $screenY)');
      positions.add(Offset(screenX, screenY));
    }
    
    debugPrint('MediaPipe earring positions: ${positions.length}');
    return positions;
  }

  Offset? _getJewelryPosition(Size screenSize) {
    if (_detectedFace == null || _controller == null) return null;

    final face = _detectedFace!;
    final landmarks = face.landmarks;
    final previewSize = _controller!.value.previewSize;
    if (previewSize == null) return null;

    final displayedWidth = previewSize.height.toDouble();
    final displayedHeight = previewSize.width.toDouble();
    final imageWidth = previewSize.width.toDouble();
    final imageHeight = previewSize.height.toDouble();
    
    final displayedAspect = displayedWidth / displayedHeight;
    final screenAspect = screenSize.width / screenSize.height;
    
    double scaleFactor;
    double offsetX = 0;
    double offsetY = 0;
    
    if (displayedAspect > screenAspect) {
      scaleFactor = screenSize.height / displayedHeight;
      final scaledWidth = displayedWidth * scaleFactor;
      offsetX = (screenSize.width - scaledWidth) / 2;
    } else {
      scaleFactor = screenSize.width / displayedWidth;
      final scaledHeight = displayedHeight * scaleFactor;
      offsetY = (screenSize.height - scaledHeight) / 2;
    }
    
    final isFrontCamera = _currentCameraDirection == CameraLensDirection.front;
    
    if (widget.jewelryType == 'earring') {
      // For earrings, we'll handle multiple positions in build method
      // This method is kept for ring tracking
      return null;
      // Position earring based on ear landmarks
      // ML Kit ear landmarks may not always be available, so we'll use fallback landmarks
      final leftEar = landmarks[FaceLandmarkType.leftEar];
      final rightEar = landmarks[FaceLandmarkType.rightEar];
      final leftCheek = landmarks[FaceLandmarkType.leftCheek];
      final rightCheek = landmarks[FaceLandmarkType.rightCheek];
      final leftEye = landmarks[FaceLandmarkType.leftEye];
      final rightEye = landmarks[FaceLandmarkType.rightEye];
      
      // Debug: log available landmarks
      debugPrint('Available landmarks - leftEar: ${leftEar != null}, rightEar: ${rightEar != null}, '
          'leftCheek: ${leftCheek != null}, rightCheek: ${rightCheek != null}, '
          'leftEye: ${leftEye != null}, rightEye: ${rightEye != null}');
      
      if (widget.side == 'left') {
        double x, y;
        
        if (leftEar != null) {
          // Use actual ear landmark if available
          x = leftEar.position.x.toDouble();
          y = leftEar.position.y.toDouble();
          debugPrint('Using leftEar landmark: image($x, $y)');
        } else if (leftCheek != null && leftEye != null) {
          // Fallback: estimate ear position from cheek and eye
          x = leftCheek.position.x.toDouble();
          y = (leftEye.position.y.toDouble() + leftCheek.position.y.toDouble()) / 2.0;
          debugPrint('Using leftCheek + leftEye fallback: image($x, $y)');
        } else if (leftCheek != null) {
          // Fallback: use cheek position
          x = leftCheek.position.x.toDouble();
          y = leftCheek.position.y.toDouble();
          debugPrint('Using leftCheek fallback: image($x, $y)');
        } else {
          debugPrint('No landmarks available for left ear');
          return null;
        }
        
        // ML Kit coordinates are in image space (imageWidth x imageHeight)
        // But preview is displayed rotated/swapped (displayedWidth x displayedHeight)
        // We need to transform coordinates from image space to displayed preview space
        
        // Since preview is displayed with swapped dimensions:
        // Image X -> Displayed Y (rotated 90 degrees)
        // Image Y -> Displayed X (rotated 90 degrees, but flipped)
        
        // Transform: swap and rotate coordinates
        var displayX = y;  // Image Y becomes displayed X
        var displayY = imageWidth - x;  // Image X becomes displayed Y (flipped)
        
        // For front camera, mirror X coordinate
        if (isFrontCamera) {
          displayX = displayedWidth - displayX;
        }
        
        // Map displayed coordinates to screen coordinates
        final screenX = (displayX * scaleFactor) + offsetX;
        final screenY = (displayY * scaleFactor) + offsetY;
        
        debugPrint('Left Ear - image($x, $y) -> display($displayX, $displayY) -> screen($screenX, $screenY)');
        debugPrint('  Image size: ${imageWidth}x${imageHeight}, Display size: ${displayedWidth}x${displayedHeight}, Screen: ${screenSize.width}x${screenSize.height}');
        
        return Offset(screenX, screenY);
      } else if (widget.side == 'right') {
        double x, y;
        
        if (rightEar != null) {
          // Use actual ear landmark if available
          x = rightEar.position.x.toDouble();
          y = rightEar.position.y.toDouble();
          debugPrint('Using rightEar landmark: image($x, $y)');
        } else if (rightCheek != null && rightEye != null) {
          // Fallback: estimate ear position from cheek and eye
          x = rightCheek.position.x.toDouble();
          y = (rightEye.position.y.toDouble() + rightCheek.position.y.toDouble()) / 2.0;
          debugPrint('Using rightCheek + rightEye fallback: image($x, $y)');
        } else if (rightCheek != null) {
          // Fallback: use cheek position
          x = rightCheek.position.x.toDouble();
          y = rightCheek.position.y.toDouble();
          debugPrint('Using rightCheek fallback: image($x, $y)');
        } else {
          debugPrint('No landmarks available for right ear');
          return null;
        }
        
        // Transform coordinates from image space to displayed preview space
        var displayX = y;  // Image Y becomes displayed X
        var displayY = imageWidth - x;  // Image X becomes displayed Y (flipped)
        
        // For front camera, mirror X coordinate
        if (isFrontCamera) {
          displayX = displayedWidth - displayX;
        }
        
        // Map displayed coordinates to screen coordinates
        final screenX = (displayX * scaleFactor) + offsetX;
        final screenY = (displayY * scaleFactor) + offsetY;
        
        debugPrint('Right Ear - image($x, $y) -> display($displayX, $displayY) -> screen($screenX, $screenY)');
        
        return Offset(screenX, screenY);
      }
    } else if (widget.jewelryType == 'ring') {
      // Position ring to approximate ring finger position
      // Use chin and bottom of face to estimate hand/ring finger location
      final bottomMouth = landmarks[FaceLandmarkType.bottomMouth];
      final leftCheek = landmarks[FaceLandmarkType.leftCheek];
      final rightCheek = landmarks[FaceLandmarkType.rightCheek];
      
      if (bottomMouth != null) {
        // Estimate ring finger position: below the chin/mouth area
        // Use cheek positions to estimate face width and center
        double centerX;
        if (leftCheek != null && rightCheek != null) {
          centerX = (leftCheek.position.x.toDouble() + rightCheek.position.x.toDouble()) / 2.0;
        } else {
          centerX = bottomMouth.position.x.toDouble();
        }
        
        // Position ring finger below the mouth (where hand would typically be)
        // Adjust Y to be lower (below chin area)
        final faceHeight = face.boundingBox.height.toDouble();
        var ringX = centerX;
        var ringY = bottomMouth.position.y.toDouble() + (faceHeight * 0.8); // Below chin
        
        // For front camera, mirror X coordinate
        if (isFrontCamera) {
          ringX = imageWidth - ringX;
        }
        
        // Map to screen coordinates using the same logic as earrings
        final screenX = (ringX * scaleFactor) + offsetX;
        final screenY = (ringY * scaleFactor) + offsetY;
        
        return Offset(screenX, screenY);
      }
    }

    return null;
  }

  // Helper method to get ear positions for visualization
  List<Offset> _getEarPositions(Size screenSize) {
    if (_detectedFace == null || _controller == null) return [];

    final face = _detectedFace!;
    final landmarks = face.landmarks;
    final previewSize = _controller!.value.previewSize;
    if (previewSize == null) return [];

    // Same coordinate transformation as _getJewelryPosition
    final displayedWidth = previewSize.height.toDouble();
    final displayedHeight = previewSize.width.toDouble();
    final imageWidth = previewSize.width.toDouble();
    final imageHeight = previewSize.height.toDouble();
    
    final displayedAspect = displayedWidth / displayedHeight;
    final screenAspect = screenSize.width / screenSize.height;
    
    double scaleFactor;
    double offsetX = 0;
    double offsetY = 0;
    
    if (displayedAspect > screenAspect) {
      scaleFactor = screenSize.height / displayedHeight;
      final scaledWidth = displayedWidth * scaleFactor;
      offsetX = (screenSize.width - scaledWidth) / 2;
    } else {
      scaleFactor = screenSize.width / displayedWidth;
      final scaledHeight = displayedHeight * scaleFactor;
      offsetY = (screenSize.height - scaledHeight) / 2;
    }
    
    final isFrontCamera = _currentCameraDirection == CameraLensDirection.front;
    final leftEar = landmarks[FaceLandmarkType.leftEar];
    final rightEar = landmarks[FaceLandmarkType.rightEar];
    final leftCheek = landmarks[FaceLandmarkType.leftCheek];
    final rightCheek = landmarks[FaceLandmarkType.rightCheek];
    final leftEye = landmarks[FaceLandmarkType.leftEye];
    final rightEye = landmarks[FaceLandmarkType.rightEye];
    
    List<Offset> earPositions = [];
    
    // Left ear
    if (leftEar != null || leftCheek != null) {
      double x, y;
      if (leftEar != null) {
        x = leftEar.position.x.toDouble();
        y = leftEar.position.y.toDouble();
      } else if (leftCheek != null && leftEye != null) {
        x = leftCheek.position.x.toDouble();
        y = (leftEye.position.y.toDouble() + leftCheek.position.y.toDouble()) / 2.0;
      } else {
        x = leftCheek!.position.x.toDouble();
        y = leftCheek.position.y.toDouble();
      }
      
      // Transform coordinates: swap and rotate
      var displayX = y;
      var displayY = imageWidth - x;
      
      if (isFrontCamera) {
        displayX = displayedWidth - displayX;
      }
      
      final screenX = (displayX * scaleFactor) + offsetX;
      final screenY = (displayY * scaleFactor) + offsetY;
      earPositions.add(Offset(screenX, screenY));
    } else {
      earPositions.add(Offset.zero);
    }
    
    // Right ear
    if (rightEar != null || rightCheek != null) {
      double x, y;
      if (rightEar != null) {
        x = rightEar.position.x.toDouble();
        y = rightEar.position.y.toDouble();
      } else if (rightCheek != null && rightEye != null) {
        x = rightCheek.position.x.toDouble();
        y = (rightEye.position.y.toDouble() + rightCheek.position.y.toDouble()) / 2.0;
      } else {
        x = rightCheek!.position.x.toDouble();
        y = rightCheek.position.y.toDouble();
      }
      
      // Transform coordinates: swap and rotate
      var displayX = y;
      var displayY = imageWidth - x;
      
      if (isFrontCamera) {
        displayX = displayedWidth - displayX;
      }
      
      final screenX = (displayX * scaleFactor) + offsetX;
      final screenY = (displayY * scaleFactor) + offsetY;
      earPositions.add(Offset(screenX, screenY));
    } else {
      earPositions.add(Offset.zero);
    }
    
    return earPositions;
  }

  // Build visual indicators for detected ears
  List<Widget> _buildEarIndicators(List<Offset> earPositions) {
    List<Widget> indicators = [];
    
    // Left ear indicator (index 0)
    if (earPositions.isNotEmpty && earPositions[0] != Offset.zero) {
      indicators.add(
        Positioned(
          left: earPositions[0].dx - 40,
          top: earPositions[0].dy - 40,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.green,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: 0.3),
                ),
                child: const Center(
                  child: Text(
                    'L',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    // Right ear indicator (index 1)
    if (earPositions.length > 1 && earPositions[1] != Offset.zero) {
      indicators.add(
        Positioned(
          left: earPositions[1].dx - 40,
          top: earPositions[1].dy - 40,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
                child: const Center(
                  child: Text(
                    'R',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return indicators;
  }

  // Build earring widget positioned at ear location (top of earring at ear position)
  Widget _buildEarringWidget({
    required Offset earPosition,
    required String glbAssetPath,
    required Size screenSize,
    required int index,
  }) {
    debugPrint('Building earring widget $index at position: $earPosition, screen size: $screenSize');
    
    // Ensure position is within screen bounds
    final clampedX = earPosition.dx.clamp(0.0, screenSize.width);
    final clampedY = earPosition.dy.clamp(0.0, screenSize.height);
    final clampedPosition = Offset(clampedX, clampedY);
    
    if (clampedPosition != earPosition) {
      debugPrint('Clamped position from $earPosition to $clampedPosition');
    }
    
    // Scale earrings based on face width: target ~10% of face width, clamped for visibility
    double scaledSize = 110.0; // default
    if (_detectedFace != null) {
      final face = _detectedFace!;
      final faceWidth = face.boundingBox.width;
      final targetSize = faceWidth * 0.10; // 10% of face width
      scaledSize = targetSize.clamp(70.0, 150.0); // smaller than before
      debugPrint('Face width: $faceWidth -> earring target size: $targetSize clamped to $scaledSize');
    }
    final earringScale = scaledSize / _baseSize;
    debugPrint('Earring $index final scale: $earringScale, scaled size: $scaledSize, position: $clampedPosition');
    
    debugPrint('Earring widget $index: Creating at clamped position: $clampedPosition, scale: $earringScale, scaledSize: $scaledSize');
    
    // ModelViewer on Android needs the asset path as declared in pubspec.yaml
    // It serves assets through a local HTTP server, so use the asset path directly
    debugPrint('Earring widget $index: Using asset path: $glbAssetPath');
    debugPrint('Earring widget $index: Position: $clampedPosition, Size: $scaledSize');
    
    return Positioned(
      left: clampedPosition.dx - scaledSize / 2,
      top: clampedPosition.dy - scaledSize / 2,
      width: scaledSize,
      height: scaledSize,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: (details) {
          _baseScale = _jewelryScale;
          _baseRotation = _rotationAngle;
        },
        onScaleUpdate: (details) {
          setState(() {
            if (details.scale != 1.0) {
              _jewelryScale = (_baseScale * details.scale).clamp(_minScale, _maxScale);
            }
            if (details.rotation != 0.0) {
              _rotationAngle = _baseRotation + details.rotation;
            }
          });
        },
        onScaleEnd: (details) {
          _baseScale = _jewelryScale;
          _baseRotation = _rotationAngle;
        },
        child: Transform.rotate(
          // Keep earrings vertical to mimic gravity; only user gestures rotate
          angle: _rotationAngle,
          child: SizedBox(
            width: scaledSize,
            height: scaledSize,
            child: ModelViewer(
              key: ValueKey('earring_$index'), // stable key to avoid recreating platform view every frame
              src: glbAssetPath, // Use asset path directly - ModelViewer serves it via HTTP
              alt: '3D Earring',
              autoRotate: false,
              cameraControls: false,
              backgroundColor: Colors.transparent,
              ar: false,
              disableZoom: true,
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to get asset path for ModelViewer on Android
  Future<String?> _getAssetPath(String assetPath) async {
    if (!Platform.isAndroid) {
      return assetPath;
    }
    
    try {
      // Try loading asset as bytes and writing to temp file
      debugPrint('Loading asset: $assetPath');
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      debugPrint('Asset loaded: ${bytes.length} bytes');
      
      if (bytes.isEmpty) {
        debugPrint('ERROR: Asset file is empty!');
        return assetPath;
      }
      
      // Write to temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = assetPath.split('/').last;
      final File tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      
      // Verify file was written
      if (!await tempFile.exists()) {
        debugPrint('ERROR: Temp file was not created!');
        return assetPath;
      }
      
      final fileSize = await tempFile.length();
      if (fileSize != bytes.length) {
        debugPrint('ERROR: File size mismatch! Expected: ${bytes.length}, Got: $fileSize');
        return assetPath;
      }
      
      // Return file path without file:// prefix - ModelViewer might handle it better
      final filePath = tempFile.path;
      debugPrint('✓ Asset copied successfully to: $filePath');
      debugPrint('✓ File exists: ${await tempFile.exists()}');
      debugPrint('✓ File size: $fileSize bytes');
      return filePath;
    } catch (e, stackTrace) {
      debugPrint('ERROR copying asset to temp file: $e');
      debugPrint('Stack trace: $stackTrace');
      // Fallback to original path
      return assetPath;
    }
  }

  // Build ring widget
  Widget _buildRingWidget({
    required Offset? ringPosition,
    required String glbAssetPath,
    required Size screenSize,
  }) {
    // Use tracked position if available, otherwise use manual position
    Offset displayPosition;
    if (_isManuallyPositioned) {
      displayPosition = _jewelryPosition;
    } else if (ringPosition != null) {
      displayPosition = ringPosition;
    } else if (_trackedPosition != Offset.zero) {
      displayPosition = _trackedPosition;
    } else {
      displayPosition = _jewelryPosition;
    }

    return Transform.translate(
      offset: Offset(
        displayPosition.dx - (_baseSize * _jewelryScale) / 2,
        displayPosition.dy - (_baseSize * _jewelryScale) / 2,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: (details) {
          _baseScale = _jewelryScale;
          _baseRotation = _rotationAngle;
          _lastPanPosition = details.localFocalPoint;
        },
        onScaleUpdate: (details) {
          setState(() {
            if (details.scale != 1.0) {
              _jewelryScale = (_baseScale * details.scale).clamp(_minScale, _maxScale);
            }
            if (details.rotation != 0.0) {
              _rotationAngle = _baseRotation + details.rotation;
            }
            final delta = details.focalPointDelta;
            if (delta.dx != 0 || delta.dy != 0) {
              _isManuallyPositioned = true;
              _jewelryPosition = Offset(
                _jewelryPosition.dx + delta.dx,
                _jewelryPosition.dy + delta.dy,
              );
            }
          });
        },
        onScaleEnd: (details) {
          _baseScale = _jewelryScale;
          _baseRotation = _rotationAngle;
        },
        child: Transform.rotate(
          angle: _rotationAngle,
          child: Transform.scale(
            scale: _jewelryScale,
            child: OverflowBox(
              minWidth: 0.0,
              minHeight: 0.0,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              alignment: Alignment.center,
              child: SizedBox(
                width: _baseSize,
                height: _baseSize,
                child: ModelViewer(
                  key: const ValueKey('ring'), // stable key
                  src: glbAssetPath, // Use asset path directly - ModelViewer serves it via HTTP
                  alt: '3D Ring',
                  autoRotate: false,
                  cameraControls: false,
                  backgroundColor: Colors.transparent,
                  ar: false,
                  disableZoom: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    
    // For earrings, get all detected ear positions (same positions where indicators were)
    final earringPositions = widget.jewelryType == 'earring' 
        ? _getEarringPositions(screenSize) 
        : <Offset>[];
    
    // Debug: log earring positions
    if (widget.jewelryType == 'earring') {
      debugPrint('Earring positions count: ${earringPositions.length}');
      for (int i = 0; i < earringPositions.length; i++) {
        debugPrint('  Earring $i: ${earringPositions[i]}');
      }
      debugPrint('Face detected: ${_detectedFace != null}');
    }
    
    // For rings, get single position
    final ringPosition = widget.jewelryType == 'ring' 
        ? _getJewelryPosition(screenSize) 
        : null;
    
    // Initialize position to center if not set
    if (_jewelryPosition == Offset.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _jewelryPosition = Offset(
              screenSize.width / 2,
              screenSize.height / 2,
            );
          });
        }
      });
    }
    
    // Determine GLB file path (assets are declared in pubspec.yaml)
    final glbFileName = widget.jewelryType == 'earring' 
        ? 'earring_test.glb' 
        : 'ring_test.glb';
    // ModelViewer on Android needs the asset path as declared in pubspec.yaml
    // Use the path directly - ModelViewer will load from assets
    final glbAssetPath = 'web/$glbFileName';
    debugPrint('GLB asset path: $glbAssetPath for jewelry type: ${widget.jewelryType}');

    return Stack(
      clipBehavior: Clip.none, // Allow overflow when scaling up
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
        
        // Visual indicators removed - tracking is confirmed correct
        
        // Earrings: Show at all detected ear positions
        // Only show unique positions (deduplicate)
        if (widget.jewelryType == 'earring' && earringPositions.isNotEmpty) ...[
          for (int i = 0; i < earringPositions.length; i++)
            _buildEarringWidget(
              earPosition: earringPositions[i],
              glbAssetPath: glbAssetPath,
              screenSize: screenSize,
              index: i, // Add index for unique keys
            ),
        ],
        
        // Ring: Show at detected position or manual position
        if (widget.jewelryType == 'ring')
          _buildRingWidget(
            ringPosition: ringPosition,
            glbAssetPath: glbAssetPath,
            screenSize: screenSize,
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
                  _detectedFace != null ? 'Face Detected' : 'Searching...',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

