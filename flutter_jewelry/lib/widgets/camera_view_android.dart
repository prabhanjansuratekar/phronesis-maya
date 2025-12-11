import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraViewAndroid extends StatefulWidget {
  final String jewelryType;
  final double scale;
  final double positionX;
  final double positionY;
  final double rotation;
  final String side;

  const CameraViewAndroid({
    super.key,
    required this.jewelryType,
    required this.scale,
    required this.positionX,
    required this.positionY,
    required this.rotation,
    this.side = 'left',
  });

  @override
  State<CameraViewAndroid> createState() => _CameraViewAndroidState();
}

class _CameraViewAndroidState extends State<CameraViewAndroid> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _permissionGranted = false;
  String? _errorMessage;
  InAppLocalhostServer? _localhostServer;
  bool _serverStarted = false;
  String? _localUrl;
  bool _triedAltLocalPath = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        // Start embedded localhost server to serve web assets with camera access
        await _startLocalServer();
        setState(() {
          _permissionGranted = true;
        });
      } else if (status.isPermanentlyDenied) {
        setState(() {
          _errorMessage = 'Camera permission denied. Please enable it in Settings > Apps > Jewelry Try-On > Permissions';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Camera permission required for AR try-on. Please grant permission when prompted.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to request camera permission: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startLocalServer() async {
    try {
      _localhostServer = InAppLocalhostServer();
      await _localhostServer!.start();
      // Assets are available under /assets/ path
      _localUrl = 'http://localhost:8080/assets/web/camera_ar.html?jewelry=${widget.jewelryType}&side=${widget.side}';
      _serverStarted = true;
    } catch (e) {
      // Fall back to hosted URL if local server fails
      _serverStarted = false;
      debugPrint('Failed to start local server: $e');
    }
  }

  @override
  void didUpdateWidget(CameraViewAndroid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_webViewController != null && 
        (oldWidget.jewelryType != widget.jewelryType ||
        oldWidget.scale != widget.scale ||
        oldWidget.positionX != widget.positionX ||
        oldWidget.positionY != widget.positionY ||
        oldWidget.rotation != widget.rotation ||
        oldWidget.side != widget.side)) {
      _updateJewelry();
    }
  }

  Future<void> _updateJewelry() async {
    if (_webViewController == null) return;
    
    final script = '''
      (function() {
        try {
          if (window.postMessage) {
            window.postMessage({
              type: 'updateJewelry',
              jewelryType: '${widget.jewelryType}',
              scale: ${widget.scale},
              positionX: ${widget.positionX},
              positionY: ${widget.positionY},
              rotation: ${widget.rotation},
              side: '${widget.side}'
            }, '*');
          }
        } catch(e) {
          console.error('Error updating jewelry:', e);
        }
      })();
    ''';
    
    try {
      // Use evaluateJavascript with lowercase 's' in javascript
      await _webViewController!.evaluateJavascript(source: script);
    } catch (e) {
      print('Error evaluating JavaScript: $e');
        // Fallback: reload production URL with latest params and cache-busting
        try {
          final url = 'https://phronesis-maya.web.app/camera_ar.html?jewelry=${widget.jewelryType}&side=${widget.side}&scale=${widget.scale}&posX=${widget.positionX}&posY=${widget.positionY}&rot=${widget.rotation}&v=${DateTime.now().millisecondsSinceEpoch}';
          await _webViewController!.loadUrl(urlRequest: URLRequest(
            url: WebUri(url),
            headers: {
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
              'Expires': '0',
            },
          ));
      } catch (e2) {
        print('Error reloading URL: $e2');
      }
    }
  }

  @override
  void dispose() {
    _localhostServer?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _errorMessage!.contains('permission') 
                    ? Icons.camera_alt_outlined 
                    : Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (_errorMessage!.contains('permission')) {
                      openAppSettings();
                    } else {
                      setState(() {
                        _errorMessage = null;
                        _isLoading = true;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade300,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(_errorMessage!.contains('permission') ? 'Open Settings' : 'Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_permissionGranted) {
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
                'Requesting camera permission...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        InAppWebView(
          // Prefer HTTPS production URL to avoid local-webview/cleartext issues
          initialUrlRequest: URLRequest(
            url: WebUri(
              'https://phronesis-maya.web.app/camera_ar.html?jewelry=${widget.jewelryType}&side=${widget.side}&scale=${widget.scale}&posX=${widget.positionX}&posY=${widget.positionY}&rot=${widget.rotation}&v=${DateTime.now().millisecondsSinceEpoch}',
            ),
            headers: {
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
              'Expires': '0',
            },
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            useHybridComposition: true,
            useShouldOverrideUrlLoading: true,
            useOnLoadResource: true,
            transparentBackground: true,
            // Set user agent to avoid Cloudflare "blocked by orb" error
            userAgent: 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            // Disable cache to force fresh loads
            cacheEnabled: false,
            clearCache: true,
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;
          },
          onLoadStart: (controller, url) {
            debugPrint('WebView load start: ${url?.toString()}');
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onLoadStop: (controller, url) async {
            debugPrint('WebView load stop: ${url?.toString()}');
            setState(() {
              _isLoading = false;
            });
            // Wait for page to fully initialize
            await Future.delayed(const Duration(milliseconds: 1000));
            _updateJewelry();
          },
          onLoadResource: (controller, resource) {
            debugPrint('WebView resource: ${resource.url}');
          },
          onLoadHttpError: (controller, url, statusCode, description) {
            debugPrint('WebView HTTP error $statusCode for ${url?.toString()}: $description');
            setState(() {
              _errorMessage = 'HTTP $statusCode while loading ${url?.toString() ?? 'unknown'}';
              _isLoading = false;
            });
          },
          onConsoleMessage: (controller, consoleMessage) {
            print('WebView Console: ${consoleMessage.message}');
          },
          onPermissionRequest: (controller, request) async {
            return PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.GRANT,
            );
          },
          onReceivedError: (controller, request, error) {
            setState(() {
              _errorMessage = 'Failed to load: ${error.description}';
              _isLoading = false;
            });
          },
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.amber,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading AR camera...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please wait...',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
