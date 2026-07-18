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
    // Gleiche Struktur wie die frühere Swipe-to-Reveal-Fläche: die Zeile
    // schiebt sich 64px nach links, dahinter liegt der rote Button — nur
    // gesteuert vom Lösch-Modus statt von einer Geste. Der Zeileninhalt
    // behält seine volle Breite und kann nicht überlaufen.
    const revealWidth = 64.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: show ? revealWidth : 0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      builder: (_, offset, child) => Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.canDelete && offset > 0)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: offset.clamp(0.0, revealWidth),
              child: GestureDetector(
                key: widget.deleteKey,
                onTap: _handleTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: offset > 24
                      ? const Icon(Icons.delete_outline,
                          color: Colors.white, size: 22)
                      : null,
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(-offset, 0),
            child: child,
          ),
        ],
      ),
      child: widget.child,
    );
  }
}
