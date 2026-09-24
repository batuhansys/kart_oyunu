import 'package:flutter/material.dart';

/// 7 saniyelik geri sayımı, kartı çevreleyen ve üstten simetrik olarak
/// kısalan bir çerçeve şeklinde çizer. progress 1.0 (süre başı) ile
/// 0.0 (süre sonu) arasında değişir.
///
/// Renk geçişi: yeşil -> sarı/turuncu -> kırmızı.
/// overrideColor verilirse (kullanıcı bir tercih yaptıysa) çerçeve o
/// sabit renkte durur: Riske Gir=mavi, Çifte Riske Gir=lacivert,
/// Pas Geç=gri.
class TimerFramePainter extends CustomPainter {
  final double progress;
  final Color? overrideColor;

  TimerFramePainter({required this.progress, this.overrideColor});

  @override
  void paint(Canvas canvas, Size size) {
    final color = overrideColor ?? _colorForProgress(progress.clamp(0.0, 1.0));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final rect = Offset.zero & size;
    final effectiveProgress = overrideColor != null ? 1.0 : progress.clamp(0.0, 1.0);

    final perimeter = 2 * (size.width + size.height);
    final drawLength = perimeter * effectiveProgress / 2;
    final topMid = Offset(size.width / 2, 0);

    _drawFromPoint(canvas, paint, rect, topMid, drawLength, clockwise: true);
    _drawFromPoint(canvas, paint, rect, topMid, drawLength, clockwise: false);
  }

  void _drawFromPoint(
    Canvas canvas,
    Paint paint,
    Rect rect,
    Offset start,
    double length, {
    required bool clockwise,
  }) {
    final points = clockwise
        ? [
            start,
            Offset(rect.right, rect.top),
            Offset(rect.right, rect.bottom),
            Offset(rect.left, rect.bottom),
            Offset(rect.left, rect.top),
            start,
          ]
        : [
            start,
            Offset(rect.left, rect.top),
            Offset(rect.left, rect.bottom),
            Offset(rect.right, rect.bottom),
            Offset(rect.right, rect.top),
            start,
          ];

    double remaining = length;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1 && remaining > 0; i++) {
      final a = points[i];
      final b = points[i + 1];
      final segmentLength = (b - a).distance;
      if (remaining >= segmentLength) {
        path.lineTo(b.dx, b.dy);
        remaining -= segmentLength;
      } else {
        final t = remaining / segmentLength;
        final point = Offset.lerp(a, b, t)!;
        path.lineTo(point.dx, point.dy);
        remaining = 0;
      }
    }
    canvas.drawPath(path, paint);
  }

  Color _colorForProgress(double p) {
    if (p > 0.5) {
      return Color.lerp(Colors.orange, Colors.green, (p - 0.5) * 2)!;
    }
    return Color.lerp(Colors.red, Colors.orange, p * 2)!;
  }

  @override
  bool shouldRepaint(covariant TimerFramePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.overrideColor != overrideColor;
}
