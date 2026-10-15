import 'package:flutter/material.dart';

/// The Helix mark, drawn from the exact logo gradients: navy tile, cyan strand,
/// violet strand, bridge rungs. The app's twin-strand identity starts here.
class HelixLogo extends StatelessWidget {
  const HelixLogo({super.key, this.size = 88});

  final double size;

  static const navy = Color(0xFF0F172A);
  static const navyDark = Color(0xFF030712);
  static const cyan = Color(0xFF06B6D4);
  static const sky = Color(0xFF0EA5E9);
  static const blue = Color(0xFF3B82F6);
  static const violet = Color(0xFF8B5CF6);
  static const fuchsia = Color(0xFFD946EF);
  static const indigo = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Helix',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LogoPainter()),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final w = s / 512; // logo is authored on a 512 grid
    final rect = Rect.fromLTWH(0, 0, s, s);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(116 * w));

    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [Color(0xFF090D16), HelixLogo.navy, HelixLogo.navyDark],
      stops: const [0, 0.5, 1],
    );
    canvas.drawRRect(rrect, Paint()..shader = bgGradient.createShader(rect));

    final cyanGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [HelixLogo.cyan, HelixLogo.sky, HelixLogo.blue],
      stops: const [0, 0.6, 1],
    );
    final violetGradient = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: const [HelixLogo.indigo, HelixLogo.violet, HelixLogo.fuchsia],
      stops: const [0, 0.5, 1],
    );

    void strand(Offset p1, Offset p2, Gradient gradient, double width, {double opacity = 1}) {
      final paint = Paint()
        ..shader = gradient.createShader(Rect.fromPoints(p1, p2))
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * w
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity);
      // gradient with alpha needs a color + shader blend; simpler: use shader only
      paint.color = const Color(0xFFFFFFFF);
      final path = Path()
        ..moveTo(p1.dx * w, p1.dy * w)
        ..cubicTo(
          p1.dx * w,
          (p1.dy + 60) * w,
          p2.dx * w,
          (p1.dy + 80) * w,
          p2.dx * w,
          (p1.dy + 120) * w,
        )
        ..cubicTo(
          p2.dx * w,
          (p1.dy + 160) * w,
          p1.dx * w,
          (p1.dy + 180) * w,
          p1.dx * w,
          (p1.dy + 240) * w,
        );
      canvas.drawPath(path, paint);
    }

    strand(const Offset(50, 40), const Offset(170, 40), cyanGradient, 24);
    strand(const Offset(170, 40), const Offset(50, 40), violetGradient, 24);

    // bridge rungs
    final bridge = Paint()
      ..shader = LinearGradient(
        colors: [
          HelixLogo.cyan.withValues(alpha: 0.85),
          HelixLogo.fuchsia.withValues(alpha: 0.85),
        ],
      ).createShader(Rect.fromLTWH(50 * w, 0, 120 * w, s))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * w
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(50 * w, 92 * w), Offset(170 * w, 108 * w), bridge);
    canvas.drawLine(Offset(170 * w, 212 * w), Offset(50 * w, 228 * w), bridge);

    // endpoint dots
    void dot(double x, double y, Color color) {
      canvas.drawCircle(Offset(x * w, y * w), 7 * w, Paint()..color = color);
    }

    dot(50, 40, const Color(0xFF67E8F9));
    dot(170, 40, const Color(0xFFF472B6));
    dot(50, 280, const Color(0xFF38BDF8));
    dot(170, 280, const Color(0xFFE879F9));
    dot(110, 160, const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
