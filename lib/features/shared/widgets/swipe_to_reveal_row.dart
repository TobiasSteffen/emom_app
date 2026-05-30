import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// Only claims leftward drags (or rightward when row is already open).
// This allows right-swipe navigation to pass through to the PageView.
class _LeftOnlyDragRecognizer extends HorizontalDragGestureRecognizer {
  _LeftOnlyDragRecognizer({super.debugOwner});
  bool _rejected = false;
  bool Function()? isClosedFn;

  @override
  void handleEvent(PointerEvent event) {
    if (_rejected) return;
    if (event is PointerMoveEvent &&
        event.delta.dx > 1.0 &&
        (isClosedFn?.call() ?? true)) {
      _rejected = true;
      resolve(GestureDisposition.rejected);
      return;
    }
    super.handleEvent(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _rejected = false;
    super.didStopTrackingLastPointer(pointer);
  }
}

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
    _ctrl.value =
        (_ctrl.value - d.delta.dx / _revealWidth).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    if (!widget.canDelete) return;
    if (_ctrl.value > 0.45 || d.velocity.pixelsPerSecond.dx < -250) {
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
    return RawGestureDetector(
      gestures: widget.canDelete
          ? {
              _LeftOnlyDragRecognizer:
                  GestureRecognizerFactoryWithHandlers<_LeftOnlyDragRecognizer>(
                () => _LeftOnlyDragRecognizer(debugOwner: this),
                (r) {
                  r.isClosedFn = () => _ctrl.value <= 0;
                  r.onUpdate = _onDragUpdate;
                  r.onEnd = _onDragEnd;
                  r.onCancel = () {
                    if (_ctrl.value != 0.0) _ctrl.animateTo(0.0);
                  };
                },
              ),
            }
          : {},
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          final offset = _ctrl.value * _revealWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.canDelete)
                Positioned(
                  right: 0,
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
                offset: Offset(-offset, 0),
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
