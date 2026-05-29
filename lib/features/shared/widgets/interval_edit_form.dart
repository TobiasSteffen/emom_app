import 'package:flutter/material.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/settings.dart';

Widget _stepButton(IconData icon, VoidCallback? onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 16,
            color: onTap != null ? Colors.white38 : Colors.white12),
      ),
    );

class IntervalEditForm extends StatefulWidget {
  final IntervalConfig iv;
  final VoidCallback onChanged;

  /// Zeilenindex — wird für automatische Seitenzuweisung bei Einarm-Übungen
  /// verwendet (gerade = links, ungerade = rechts).
  final int? index;

  /// Optionaler Callback für den Einklappen-Button am unteren Rand.
  final VoidCallback? onCollapse;

  /// Wird aufgerufen direkt BEVOR eine Feldmutation stattfindet.
  /// Ermöglicht dem Parent, einen Snapshot für Undo zu erstellen.
  final VoidCallback? onBeforeChange;

  const IntervalEditForm({
    super.key,
    required this.iv,
    required this.onChanged,
    this.index,
    this.onCollapse,
    this.onBeforeChange,
  });

  @override
  State<IntervalEditForm> createState() => _IntervalEditFormState();
}

class _IntervalEditFormState extends State<IntervalEditForm> {
  // Resets automatically when this widget is recreated (key change).
  // Known: stale picker state when same row is collapsed and re-expanded without key change.
  String? _openPicker;

  void _update(VoidCallback fn) {
    widget.onBeforeChange?.call();
    setState(fn);
    widget.onChanged();
  }

  void _togglePicker(String picker) {
    setState(() {
      _openPicker = _openPicker == picker ? null : picker;
    });
  }

  Widget _pickerChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFF6B00)
                : const Color(0xFF222222),
            borderRadius: BorderRadius.circular(6),
            border: selected ? null : Border.all(color: Colors.white12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.black : Colors.white54,
            ),
          ),
        ),
      );

  Widget _formSectionHeader(String label, String value, String picker) =>
      GestureDetector(
        onTap: () => _togglePicker(picker),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.white38)),
              ),
              Expanded(
                child: Text(value,
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ),
              Icon(
                _openPicker == picker ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: Colors.white24,
              ),
            ],
          ),
        ),
      );

  Widget _formRow(String label, Widget content) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.white38)),
            ),
            content,
          ],
        ),
      );

  Widget _stepper({
    required String display,
    required VoidCallback onInc,
    VoidCallback? onDec,
  }) =>
      Row(
        children: [
          _stepButton(Icons.remove, onDec),
          SizedBox(
            width: 40,
            child: Center(
              child: Text(display,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70)),
            ),
          ),
          _stepButton(Icons.add, onInc),
        ],
      );

  Widget _equipmentGroup(
    String iconPath,
    List<Equipment> items,
    Equipment current,
    void Function(Equipment) onSelect,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Image.asset(iconPath, width: 14, height: 14,
                  color: Colors.white38),
            ),
            Expanded(
              child: Wrap(
                children: [
                  for (final eq in items)
                    _pickerChip(eq.shortLabel, current == eq, () => onSelect(eq)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final iv = widget.iv;

    void selectEquipment(Equipment eq) => _update(() {
          iv.equipment = eq;
          if (!eq.validExercises.contains(iv.exercise)) {
            iv.exercise = eq.defaultExercise;
          }
          final resolvedExercise = iv.exercise;
          if (resolvedExercise.isOneArm && iv.side == null) {
            iv.side = (widget.index ?? 0) % 2 == 0
                ? ExerciseSide.links
                : ExerciseSide.rechts;
          }
          if (!resolvedExercise.isOneArm) iv.side = null;
        });

    void selectExercise(Exercise ex) => _update(() {
          iv.exercise = ex;
          if (ex.isOneArm && iv.side == null) {
            iv.side = (widget.index ?? 0) % 2 == 0
                ? ExerciseSide.links
                : ExerciseSide.rechts;
          }
          if (!ex.isOneArm) iv.side = null;
        });

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pause-Toggle
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                if (iv.isPause) {
                  _update(() => iv.isPause = false);
                } else {
                  _update(() {
                    _openPicker = null;
                    iv.isPause = true;
                    iv.side = null;
                  });
                }
              },
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: iv.isPause
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(6),
                  border: iv.isPause
                      ? null
                      : Border.all(color: Colors.white12),
                ),
                child: Text(
                  'Pause',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        iv.isPause ? FontWeight.bold : FontWeight.normal,
                    color: iv.isPause ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ),
          ),
          // Gerät / Übung / Seite / Wiederholungen (ausgeblendet wenn Pause)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
            crossFadeState: iv.isPause
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Colors.white12, height: 1),
                _formSectionHeader('Gerät', iv.equipment.label, 'equipment'),
                if (_openPicker == 'equipment')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _equipmentGroup(
                          'assets/icon/kettlebell.png',
                          Equipment.values
                              .where((e) => e.isKettlebell)
                              .toList(),
                          iv.equipment,
                          selectEquipment,
                        ),
                        _equipmentGroup(
                          'assets/icon/steelmace.png',
                          Equipment.values
                              .where((e) => e.isSteelMace)
                              .toList(),
                          iv.equipment,
                          selectEquipment,
                        ),
                        _equipmentGroup(
                          'assets/icon/pezziball.png',
                          Equipment.values
                              .where((e) => e.isPezziball)
                              .toList(),
                          iv.equipment,
                          selectEquipment,
                        ),
                      ],
                    ),
                  ),
                const Divider(color: Colors.white12, height: 1),
                _formSectionHeader(
                    'Übung', iv.exercise.label, 'exercise'),
                if (_openPicker == 'exercise')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      children: [
                        for (final ex in iv.equipment.validExercises)
                          _pickerChip(ex.label, iv.exercise == ex,
                              () => selectExercise(ex)),
                      ],
                    ),
                  ),
                if (iv.exercise.isOneArm) ...[
                  const Divider(color: Colors.white12, height: 1),
                  _formRow(
                    'Seite',
                    Row(
                      children: [
                        _pickerChip(
                            'Links',
                            iv.side == ExerciseSide.links,
                            () => _update(
                                () => iv.side = ExerciseSide.links)),
                        const SizedBox(width: 6),
                        _pickerChip(
                            'Rechts',
                            iv.side == ExerciseSide.rechts,
                            () => _update(
                                () => iv.side = ExerciseSide.rechts)),
                      ],
                    ),
                  ),
                ],
                const Divider(color: Colors.white12, height: 1),
                _formRow(
                  'Wiederholungen',
                  _stepper(
                    display: '${iv.reps}',
                    onDec: iv.reps > 1
                        ? () => _update(() => iv.reps--)
                        : null,
                    onInc: () => _update(() => iv.reps++),
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
          const Divider(color: Colors.white12, height: 1),
          _formRow(
            'Sekunden',
            _stepper(
              display: '${iv.durationSeconds}',
              onDec: iv.durationSeconds > 30
                  ? () => _update(() => iv.durationSeconds =
                      (iv.durationSeconds - 5).clamp(30, 9999))
                  : null,
              onInc: () => _update(() => iv.durationSeconds += 5),
            ),
          ),
          if (widget.onCollapse != null)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: widget.onCollapse,
                child: const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 8),
                  child:
                      Icon(Icons.expand_less, size: 20, color: Colors.white24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
