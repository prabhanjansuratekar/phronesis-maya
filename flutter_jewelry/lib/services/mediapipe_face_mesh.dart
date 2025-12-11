import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:image/image.dart' as img;

/// MediaPipe Face Mesh service for detecting 468 facial landmarks
/// Uses face_detection_tflite which implements MediaPipe's face mesh model
class MediaPipeFaceMesh {
  static FaceDetector? _faceDetector;
  static bool _isInitialized = false;
  
  /// Initialize MediaPipe Face Mesh (using face_detection_tflite)
  static Future<bool> initialize() async {
    if (_isInitialized && _faceDetector != null) {
      return true;
    }
    
    try {
      // Temporarily disable MediaPipe (face_detection_tflite) because initialization is failing
      // and causing repeated errors. Fallback to ML Kit for now.
      print('MediaPipe: Disabled (falling back to ML Kit)');
      _isInitialized = false;
      _faceDetector = null;
      return false;
    } catch (e, stackTrace) {
      print('MediaPipe initialization error: $e');
      print('Stack trace: $stackTrace');
      _isInitialized = false;
      _faceDetector = null;
      return false;
    }
  }
  
  /// Process camera image and get face landmarks
  /// Returns list of 468 landmarks (x, y, z) normalized to [0, 1]
  static Future<List<Map<String, double>>?> processImage(CameraImage image) async {
    if (!_isInitialized || _faceDetector == null) {
      print('MediaPipe: Not initialized, skipping detection');
      return null;
    }
    
    try {
      // Convert CameraImage to Uint8List (PNG bytes) for face_detection_tflite
      final img.Image? convertedImage = _convertCameraImageToImage(image);
      if (convertedImage == null) {
        print('MediaPipe: Failed to convert CameraImage');
        return null;
      }
      
      // Convert img.Image to PNG bytes (Uint8List)
      final pngBytes = Uint8List.fromList(img.encodePng(convertedImage));
      print('MediaPipe: Converted image to PNG, size: ${pngBytes.length} bytes');
      
      // Process with face detector
      // face_detection_tflite API: detectFaces(Uint8List) returns PipelineResult
      final result = await _faceDetector!.detectFaces(pngBytes);
      
      // PipelineResult contains faces
      if (result.faces.isEmpty) {
        print('MediaPipe: No faces detected');
        return null;
      }
      
      // Get the first face's mesh (468 landmarks)
      final face = result.faces.first;
      final mesh = face.mesh;
      
      if (mesh.length < 468) {
        print('MediaPipe: Expected 468 landmarks, got ${mesh.length}');
        return null;
      }
      
      // Convert mesh points to normalized coordinates [0, 1]
      // face_detection_tflite returns points in image pixel coordinates
      // Point<double> from dart:math only has x and y, no z
      final landmarks = mesh.map<Map<String, double>>((point) {
        return {
          'x': point.x / image.width,
          'y': point.y / image.height,
          'z': 0.0, // Z depth not available in Point<double>, set to 0
        };
      }).toList();
      
      print('MediaPipe: Successfully detected ${landmarks.length} landmarks');
      return landmarks;
    } catch (e, stackTrace) {
      print('MediaPipe processImage error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Convert CameraImage to img.Image format
  static img.Image? _convertCameraImageToImage(CameraImage cameraImage) {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        // Convert YUV420 to RGB
        final yPlane = cameraImage.planes[0];
        final uPlane = cameraImage.planes.length > 1 ? cameraImage.planes[1] : null;
        final vPlane = cameraImage.planes.length > 2 ? cameraImage.planes[2] : null;
        
        // Create image from YUV planes
        final image = img.Image(
          width: cameraImage.width,
          height: cameraImage.height,
        );
        
        // Convert YUV to RGB
        for (int y = 0; y < cameraImage.height; y++) {
          for (int x = 0; x < cameraImage.width; x++) {
            final yIndex = y * yPlane.bytesPerRow + x;
            final uvIndex = (y ~/ 2) * (uPlane?.bytesPerRow ?? 0) + (x ~/ 2);
            
            final yValue = yPlane.bytes[yIndex];
            final uValue = uPlane?.bytes[uvIndex] ?? 128;
            final vValue = vPlane?.bytes[uvIndex] ?? 128;
            
            // YUV to RGB conversion
            final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
            final g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128)).clamp(0, 255).toInt();
            final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();
            
            image.setPixelRgba(x, y, r, g, b, 255); // Add alpha channel
          }
        }
        
        return image;
      } else {
        // For other formats, try to convert
        return null;
      }
    } catch (e) {
      print('Error converting CameraImage: $e');
      return null;
    }
  }
  
  /// Dispose MediaPipe resources
  static Future<void> dispose() async {
    try {
      // face_detection_tflite doesn't have a close method, just clear reference
      _faceDetector = null;
      _isInitialized = false;
    } catch (e) {
      print('MediaPipe dispose error: $e');
    }
  }
  
  /// MediaPipe Face Mesh landmark indices for ears
  /// Based on MediaPipe Face Mesh 468 landmark model
  static const int LEFT_EAR_TOP = 234;
  static const int LEFT_EAR_BOTTOM = 454;
  static const int RIGHT_EAR_TOP = 454;
  static const int RIGHT_EAR_BOTTOM = 234;
  
  /// Get left ear position from landmarks
  static Map<String, double>? getLeftEarPosition(List<Map<String, double>> landmarks) {
    if (landmarks.length < 468) return null;
    
    final top = landmarks[LEFT_EAR_TOP];
    final bottom = landmarks[LEFT_EAR_BOTTOM];
    
    return {
      'x': (top['x']! + bottom['x']!) / 2,
      'y': (top['y']! + bottom['y']!) / 2,
      'z': (top['z']! + bottom['z']!) / 2,
    };
  }
  
  /// Get right ear position from landmarks
  static Map<String, double>? getRightEarPosition(List<Map<String, double>> landmarks) {
    if (landmarks.length < 468) return null;
    
    // Note: MediaPipe uses same indices but mirrored for right ear
    // We need to find the right ear landmarks (typically around index 454)
    // For now, using approximate positions
    if (landmarks.length > 234) {
      final rightEarTop = landmarks[234]; // Approximate
      final rightEarBottom = landmarks[454]; // Approximate
      
      return {
        'x': (rightEarTop['x']! + rightEarBottom['x']!) / 2,
        'y': (rightEarTop['y']! + rightEarBottom['y']!) / 2,
        'z': (rightEarTop['z']! + rightEarBottom['z']!) / 2,
      };
    }
    
    return null;
  }
}

