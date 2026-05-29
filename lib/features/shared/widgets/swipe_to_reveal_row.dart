import 'package:flutter/material.dart';

class SwipeToRevealRow extends StatefulWidget {
  final bool canDelete;
  final Future<void> Function() onDeleteTap;
  final Widget child;
  final Key? deleteKey;

  const SwipeToRevealRow({
    super.key,
    required this.canDelete,
    required this.onDeleteTap,
    required this.child,
    this.deleteKey,
  });

  @override
  State<SwipeToRevealRow> createState() => _SwipeToRevealRowState();
}

class _SwipeToRevealRowState extends State<SwipeToRevealRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const double _revealWidth = 64.0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!widget.canDelete) return;
    _ctrl.value =
        (_ctrl.value + d.delta.dx / _revealWidth).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    if (!widget.canDelete) return;
    if (_ctrl.value > 0.45 || d.velocity.pixelsPerSecond.dx > 250) {
      _ctrl.animateTo(1.0);
    } else {
      _ctrl.animateTo(0.0);
    }
  }

  Future<void> _handleDeleteTap() async {
    if (_busy) return;
    _busy = true;
    try {
      await widget.onDeleteTap();
    } finally {
      _busy = false;
      if (mounted) _ctrl.animateTo(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: () {
        if (_ctrl.value != 0.0) _ctrl.animateTo(0.0);
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          final offset = _ctrl.value * _revealWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.canDelete)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: offset.clamp(0.0, _revealWidth),
                  child: GestureDetector(
                    key: widget.deleteKey,
                    onTap: _handleDeleteTap,
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
                offset: Offset(offset, 0),
                child: child,
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}
