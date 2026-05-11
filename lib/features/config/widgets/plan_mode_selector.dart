import 'package:flutter/material.dart';
import '../../../core/models/settings.dart';

class PlanModeSelector extends StatelessWidget {
  final PlanMode planMode;
  final ValueChanged<PlanMode> onChanged;

  const PlanModeSelector({
    super.key,
    required this.planMode,
    required this.onChanged,
  });

  Widget _radioBtn(String label, PlanMode mode) {
    final active = planMode == mode;
    return GestureDetector(
      onTap: () => onChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E1E1E) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? const Color(0xFF333333) : const Color(0xFF1A1A1A)),
        ),
        child: Center(
          child: Text('${active ? "●" : "○"} $label',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.5,
                  color: active ? Colors.white54 : Colors.white12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: _radioBtn('Phasen-basiert', PlanMode.phaseBased)),
          const SizedBox(width: 8),
          Expanded(child: _radioBtn('Minuten-genau', PlanMode.minuteExact)),
        ],
      ),
    );
  }
}
