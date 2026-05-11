import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class EquipmentSelector extends StatelessWidget {
  final Equipment equipment;
  final ValueChanged<Equipment> onChanged;

  const EquipmentSelector({
    super.key,
    required this.equipment,
    required this.onChanged,
  });

  Widget _btn(String label, Equipment eq, String iconPath) {
    final active = equipment == eq;
    return GestureDetector(
      onTap: () => onChanged(eq),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E1E1E) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? const Color(0xFF333333) : const Color(0xFF1A1A1A)),
        ),
        child: Column(
          children: [
            Image.asset(iconPath,
                width: 32,
                height: 32,
                color: active ? const Color(0xFFFF6B00) : Colors.white12),
            const SizedBox(height: 6),
            Text('${active ? "●" : "○"} $label',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: active ? Colors.white54 : Colors.white12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              child: _btn(
                  'Kettlebell', Equipment.kettlebell, 'assets/icon/kettlebell.png')),
          const SizedBox(width: 8),
          Expanded(
              child: _btn(
                  'Steel Mace', Equipment.steelmace, 'assets/icon/steelmace.png')),
        ],
      ),
    );
  }
}
