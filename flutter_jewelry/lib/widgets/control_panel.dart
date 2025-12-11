import 'package:flutter/material.dart';

class ControlPanel extends StatelessWidget {
  final double scale;
  final double positionX;
  final double positionY;
  final double rotation;
  final Function(double) onScaleChanged;
  final Function(double) onPositionXChanged;
  final Function(double) onPositionYChanged;
  final Function(double) onRotationChanged;
  final VoidCallback onReset;

  const ControlPanel({
    super.key,
    required this.scale,
    required this.positionX,
    required this.positionY,
    required this.rotation,
    required this.onScaleChanged,
    required this.onPositionXChanged,
    required this.onPositionYChanged,
    required this.onRotationChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Adjust Fit',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildSlider(
            label: 'Size',
            icon: Icons.zoom_in,
            value: scale,
            min: 0.5,
            max: 2.0,
            onChanged: onScaleChanged,
            valueLabel: '${(scale * 100).toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Left / Right',
            icon: Icons.swap_horiz,
            value: positionX,
            min: -50.0,
            max: 50.0,
            onChanged: onPositionXChanged,
            valueLabel: positionX.toStringAsFixed(1),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Up / Down',
            icon: Icons.swap_vert,
            value: positionY,
            min: -50.0,
            max: 50.0,
            onChanged: onPositionYChanged,
            valueLabel: positionY.toStringAsFixed(1),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Rotate',
            icon: Icons.rotate_right,
            value: rotation,
            min: -180.0,
            max: 180.0,
            onChanged: onRotationChanged,
            valueLabel: '${rotation.toStringAsFixed(0)}°',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text(
                'Reset to Default',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
    required String valueLabel,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.shade300.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.amber.shade300, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade300.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      valueLabel,
                      style: TextStyle(
                        color: Colors.amber.shade300,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
                activeColor: Colors.amber.shade300,
                inactiveColor: Colors.grey.shade700,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
