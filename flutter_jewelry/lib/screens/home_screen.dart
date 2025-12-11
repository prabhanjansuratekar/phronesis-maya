import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../widgets/camera_view.dart';
import '../widgets/jewelry_selector.dart';
import '../widgets/control_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedJewelry = 'earring';
  String earringSide = 'left';
  double scale = 1.0;
  double positionX = 0.0;
  double positionY = 0.0;
  double rotation = 0.0;
  bool showControls = true;
  bool cameraEnabled = false;
  CameraLensDirection cameraDirection = CameraLensDirection.front;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Jewelry Try-On',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (cameraEnabled) ...[
            IconButton(
              icon: Icon(
                cameraDirection == CameraLensDirection.front
                    ? Icons.camera_rear
                    : Icons.camera_front,
                color: Colors.white,
              ),
              tooltip: 'Switch Camera',
              onPressed: () {
                setState(() {
                  cameraDirection = cameraDirection == CameraLensDirection.front
                      ? CameraLensDirection.back
                      : CameraLensDirection.front;
                });
              },
            ),
            IconButton(
              icon: Icon(
                showControls ? Icons.visibility_off : Icons.visibility,
                color: Colors.white,
              ),
              tooltip: showControls ? 'Hide Controls' : 'Show Controls',
              onPressed: () {
                setState(() {
                  showControls = !showControls;
                });
              },
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // Camera view or welcome screen
          if (cameraEnabled)
            CameraView(
              jewelryType: selectedJewelry,
              scale: scale,
              positionX: positionX,
              positionY: positionY,
              rotation: rotation,
              side: earringSide,
              cameraDirection: cameraDirection,
            )
          else
            _buildWelcomeScreen(),

          // Control panels
          if (showControls && cameraEnabled) ...[
            // Top: Jewelry selector
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      JewelrySelector(
                        selectedJewelry: selectedJewelry,
                        onJewelryChanged: (jewelry) {
                          setState(() {
                            selectedJewelry = jewelry;
                          });
                        },
                      ),
                      // Side selector for earrings
                      if (selectedJewelry == 'earring')
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSideButton('left', 'L', 'Left Ear'),
                              const SizedBox(width: 8),
                              _buildSideButton('right', 'R', 'Right Ear'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom: Control panel
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: ControlPanel(
                  scale: scale,
                  positionX: positionX,
                  positionY: positionY,
                  rotation: rotation,
                  onScaleChanged: (value) {
                    setState(() {
                      scale = value;
                    });
                  },
                  onPositionXChanged: (value) {
                    setState(() {
                      positionX = value;
                    });
                  },
                  onPositionYChanged: (value) {
                    setState(() {
                      positionY = value;
                    });
                  },
                  onRotationChanged: (value) {
                    setState(() {
                      rotation = value;
                    });
                  },
                  onReset: () {
                    setState(() {
                      scale = 1.0;
                      positionX = 0.0;
                      positionY = 0.0;
                      rotation = 0.0;
                    });
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            Colors.grey.shade900,
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade300.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.diamond,
                    size: 100,
                    color: Colors.amber.shade300,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Jewelry Try-On AR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Try on ${selectedJewelry == 'earring' ? 'earrings' : 'rings'} in real-time using AR',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureItem(Icons.camera_alt, 'Real-time AR'),
                      const SizedBox(height: 16),
                      _buildFeatureItem(Icons.tune, 'Adjustable Fit'),
                      const SizedBox(height: 16),
                      _buildFeatureItem(Icons.face, 'Face Tracking'),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        cameraEnabled = true;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade300,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Start AR Try-On',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Jewelry selector on welcome screen
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: JewelrySelector(
                    selectedJewelry: selectedJewelry,
                    onJewelryChanged: (jewelry) {
                      setState(() {
                        selectedJewelry = jewelry;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.amber.shade300, size: 24),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildSideButton(String side, String label, String tooltip) {
    final isSelected = earringSide == side;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          setState(() {
            earringSide = side;
          });
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.amber.shade300
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? Colors.amber.shade300 : Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
