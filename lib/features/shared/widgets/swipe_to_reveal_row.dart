import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// Only claims leftward drags (or rightward when row is already open).
// This allows right-swipe navigation to pass through to the PageView.
//
// The reject decision uses cumulative movement since pointer-down, not
// single events: real fingers jitter 1-3px in random directions at
// touch-down, which must not kill a genuine left swipe.
class _LeftOnlyDragRecognizer extends HorizontalDragGestureRecognizer {
  _LeftOnlyDragRecognizer({super.debugOwner});
  static const double _rejectNetDx = 8.0;
  // Below the ~18px touch slop other arena members (tap, delayed
  // long-press drag) use, but well above the 1-3px jitter real fingers
  // produce on pointer-down. Crossing this net displacement is a clear
  // directional intent, not a tap or accidental jitter. Claiming the
  // arena eagerly here beats the ReorderableDelayedDragStartListener's
  // long-press timer, which otherwise wins against slow left swipes.
  static const double _eagerAcceptDx = 10.0;
  double _netDx = 0.0;
  double _netDy = 0.0;
  bool _rejected = false;
  bool _accepted = false;
  bool Function()? isClosedFn;

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    super.acceptGesture(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (_rejected) return;
    if (event is PointerMoveEvent && !_accepted) {
      _netDx += event.delta.dx;
      _netDy += event.delta.dy;
      final closed = isClosedFn?.call() ?? true;
      if (closed) {
        // Rightward swipes on a closed row must fall through to the
        // screen-level right-fling-back detector.
        if (_netDx > _rejectNetDx) {
          _rejected = true;
          resolve(GestureDisposition.rejected);
          return;
        }
        // Deliberate leftward movement that dominates any vertical
        // drift: claim the arena now instead of waiting for slop/timer
        // races.
        if (_netDx <= -_eagerAcceptDx && _netDx.abs() >= _netDy.abs()) {
          resolve(GestureDisposition.accepted);
        }
      } else {
        // Row already open: both further-left reveal and right-to-close
        // belong to us; the vertical-dominance guard keeps list scrolls
        // untouched.
        if (_netDx.abs() >= _eagerAcceptDx && _netDx.abs() >= _netDy.abs()) {
          resolve(GestureDisposition.accepted);
        }
      }
    }
    super.handleEvent(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _rejected = false;
    _accepted = false;
    _netDx = 0.0;
    _netDy = 0.0;
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
