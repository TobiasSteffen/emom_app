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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.white, size: 20),
                    ),
                  ),
                )
              : const SizedBox(height: 36),
        ),
      ],
    );
  }
}
