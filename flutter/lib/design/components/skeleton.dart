import 'package:flutter/material.dart';
import '../tokens.dart';

/// Pulsing skeleton bars. Honours reduced-motion (static). Announced once.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.lines = 1});

  final double height;
  final double? width;
  final int lines;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduce && !_controller.isAnimating) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = 0.5 + 0.5 * _controller.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.lines; i++) ...[
                if (i > 0) const SizedBox(height: AppSpace.s2),
                Container(
                  height: widget.height,
                  width: widget.width ?? double.infinity,
                  decoration: BoxDecoration(
                    color: Color.lerp(AppColors.surfaceSunk, AppColors.line, t),
                    borderRadius: BorderRadius.circular(AppRadius.control - 4),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
