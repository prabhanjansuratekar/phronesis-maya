import 'package:flutter/material.dart';

class JewelrySelector extends StatelessWidget {
  final String selectedJewelry;
  final Function(String) onJewelryChanged;

  const JewelrySelector({
    super.key,
    required this.selectedJewelry,
    required this.onJewelryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildJewelryButton('earring', 'Earring', Icons.diamond_outlined),
          const SizedBox(width: 12),
          _buildJewelryButton('ring', 'Ring', Icons.circle_outlined),
        ],
      ),
    );
  }

  Widget _buildJewelryButton(String type, String label, IconData icon) {
    final isSelected = selectedJewelry == type;
    return GestureDetector(
      onTap: () => onJewelryChanged(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.amber.shade300.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.amber.shade300 : Colors.grey.shade700,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.amber.shade300 : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.amber.shade300 : Colors.grey.shade400,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
