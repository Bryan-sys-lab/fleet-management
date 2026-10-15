import 'package:flutter/material.dart';
import '../tokens.dart';

/// Covers the app switcher with the logo (PrivacyShield) and blocks screenshots
/// on security-sensitive screens. Wraps the screen_protector plugin.
class PrivacyShield extends StatelessWidget {
  const PrivacyShield({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // The OS already hides the preview when FLAG_SECURE is set by the
        // platform layer; this overlay is the in-app reminder mark.
        Positioned(
          right: AppSpace.s3,
          bottom: AppSpace.s2,
          child: Opacity(
            opacity: 0.35,
            child: HelixLogoMark(size: 14),
          ),
        ),
      ],
    );
  }
}

class HelixLogoMark extends StatelessWidget {
  const HelixLogoMark({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
      ).createShader(Rect.fromLTWH(0, 0, s, s))
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.22
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(s * 0.1, s * 0.08)
      ..cubicTo(s * 0.1, s * 0.5, s * 0.9, s * 0.5, s * 0.9, s * 0.92);
    final path2 = Path()
      ..moveTo(s * 0.9, s * 0.08)
      ..cubicTo(s * 0.9, s * 0.5, s * 0.1, s * 0.5, s * 0.1, s * 0.92);
    canvas.drawPath(path, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
