import 'package:flutter/material.dart';

/// Zeileninhalt mit einblendbarem Lösch-Button rechts. Ersetzt die frühere
/// Swipe-to-Reveal-Geste: Löschen ist ein expliziter Modus, keine Geste.
class DeleteModeRow extends StatefulWidget {
  final bool deleteMode;
  final bool canDelete;
  final Future<void> Function() onDeleteTap;
  final Widget child;
  final Key? deleteKey;

  const DeleteModeRow({
    super.key,
    required this.deleteMode,
    required this.canDelete,
    required this.onDeleteTap,
    required this.child,
    this.deleteKey,
  });

  @override
  State<DeleteModeRow> createState() => _DeleteModeRowState();
}

class _DeleteModeRowState extends State<DeleteModeRow> {
  bool _busy = false;

  Future<void> _handleTap() async {
    if (_busy) return;
    _busy = true;
    try {
      await widget.onDeleteTap();
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = widget.deleteMode && widget.canDelete;
    // Lösch-Modus als Layout-Änderung, nicht als Verschiebung: der Button
    // bekommt rechts einen echten Slot, der Zeileninhalt wird per Expanded
    // auf die Restbreite gestaucht — nichts ragt aus dem Bildschirm.
    const revealWidth = 64.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: show ? revealWidth : 0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      builder: (_, slot, child) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Expanded(child: child!),
          if (widget.canDelete && slot > 0)
            SizedBox(
              width: slot.clamp(0.0, revealWidth),
              child: GestureDetector(
                key: widget.deleteKey,
                onTap: _handleTap,
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: slot > 24
                      ? const Icon(Icons.delete_outline,
                          color: Colors.white, size: 22)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
      child: widget.child,
    );
  }
}
