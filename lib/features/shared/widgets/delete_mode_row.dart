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
    // Optik wie die frühere Swipe-to-Reveal-Fläche: rotes abgerundetes
    // Rechteck in voller Zeilenhöhe rechts neben dem Inhalt.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: widget.child),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            child: show
                ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      key: widget.deleteKey,
                      onTap: _handleTap,
                      child: Container(
                        width: 64,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
