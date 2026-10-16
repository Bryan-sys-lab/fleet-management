import 'package:flutter/material.dart';
import '../motion.dart';
import '../theme.dart';
import '../tokens.dart';

/// Modal bottom sheets for pickers and contextual actions: drag handle,
/// swipe-to-dismiss AND a visible close button, safe-area aware.
///
/// The sheet tracks the finger 1:1 while dragging; on release it springs to
/// its nearest detent carrying the release velocity (interruptible, redirectable
/// at any instant — apple-design §3–5). Reduced motion degrades to an instant,
/// fully-visible sheet.
class SheetHost extends StatefulWidget {
  const SheetHost({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      barrierColor: AppColors.surfaceInverse.withValues(alpha: 0.25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (context) => FrostedSurface(
        blur: AppColors.blurSheet,
        color: AppColors.frostSheet,
        child: SheetHost(title: title, child: child),
      ),
    );
  }

  @override
  State<SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<SheetHost> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.durSheet,
  )..value = 1.0;
  double? _sheetHeight;
  double _dragStartValue = 1.0;
  double _dragStartY = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  double get _closedY => (_sheetHeight ?? MediaQuery.sizeOf(context).height);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _dragStartValue = _controller.value;
    _dragStartY = details.globalPosition.dy;
    _controller.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.globalPosition.dy - _dragStartY;
    final height = _closedY;
    if (height == 0) return;
    final newValue = (_dragStartValue - delta / height).clamp(0.0, 1.0);
    _controller.value = newValue;
  }

  void _onDragEnd(DragEndDetails details) {
    if (_reduceMotion) {
      if (_controller.value < 0.5) Navigator.of(context).pop();
      return;
    }
    final height = _closedY;
    final currentY = height * (1.0 - _controller.value);
    // direction: moving down → close, moving up → open
    final velocityY = details.primaryVelocity ?? 0;
    // commit to the nearest detent, carrying release velocity; a strong push
    // past halfway commits even if the finger hasn't reached the detent yet
    final commitValue = velocityY > 400
        ? 0.0
        : velocityY < -400
            ? 1.0
            : _controller.value > 0.5
                ? 1.0
                : 0.0;
    final commitY = height * (1.0 - commitValue);
    springTo(_controller, commitValue,
        description: AppSpring.drawer(),
        velocity: gestureVelocityToSpring(
          velocityY,
          currentY,
          commitY,
        ));
    if (commitValue == 0.0) {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _sheetHeight = constraints.maxHeight;
        final open = AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final y = _closedY * (1.0 - _controller.value);
            return Transform.translate(
              offset: Offset(0, y),
              child: child,
            );
          },
          child: _SheetBody(title: widget.title, child: widget.child),
        );
        return GestureDetector(
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          behavior: HitTestBehavior.translucent,
          child: open,
        );
      },
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpace.s3),
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.s5, AppSpace.s4, AppSpace.s2, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title ?? '',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textSecondary),
                      tooltip: 'Dismiss',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            Flexible(child: child),
            const SizedBox(height: AppSpace.s4),
          ],
        ),
      ),
    );
  }
}

