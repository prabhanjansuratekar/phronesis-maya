import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../widgets/camera_view.dart';
import '../widgets/jewelry_selector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedJewelry = 'earring';
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
          ],
        ],
      ),
      body: Stack(
        children: [
          if (cameraEnabled)
            CameraView(
              jewelryType: selectedJewelry,
              scale: 1.0,
              positionX: 0.0,
              positionY: 0.0,
              rotation: 0.0,
              side: 'left',
              cameraDirection: cameraDirection,
            )
          else
            _buildWelcomeScreen(),
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
                  'Try on earrings in real-time using AR',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                const SizedBox(height: 32),
                _buildProductCard(
                  title: 'Earrings',
                  subtitle: 'Try virtually and view in 3D',
                  glbAssetPath: 'web/earring_test.glb',
                  enableTry: true,
                  onTry: () {
                    setState(() {
                      selectedJewelry = 'earring';
                      cameraEnabled = true;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildProductCard(
                  title: 'Ring',
                  subtitle: '3D preview available • Try-on coming soon',
                  glbAssetPath: 'web/ring_test.glb',
                  enableTry: false,
                  onTry: () {},
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

  Widget _buildProductCard({
    required String title,
    required String subtitle,
    required String glbAssetPath,
    required bool enableTry,
    required VoidCallback onTry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _show3DViewer(title, glbAssetPath),
                icon: const Icon(Icons.threed_rotation),
                label: const Text('View 3D'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              ElevatedButton(
                onPressed: enableTry ? onTry : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      enableTry ? Colors.amber.shade300 : Colors.grey.shade700,
                  foregroundColor: enableTry ? Colors.black : Colors.white,
                  elevation: enableTry ? 2 : 0,
                  minimumSize: const Size(0, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text(enableTry ? 'Try virtually' : 'Coming soon'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _show3DViewer(String title, String glbAssetPath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$title 3D Preview',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 360,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ModelViewer(
                    src: glbAssetPath,
                    alt: '$title 3D model',
                    ar: false,
                    autoRotate: true,
                    cameraControls: true,
                    backgroundColor: Colors.transparent,
                    interactionPrompt: InteractionPrompt.none,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
