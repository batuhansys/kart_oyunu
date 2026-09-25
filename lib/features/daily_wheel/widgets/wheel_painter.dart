import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 6 dilimli çark çizimi. Dilim 0 tam üstten (saat 12 yönü) başlar ve
/// saat yönünde ilerler - dış widget'taki sabit ibre de üstte olduğu
/// için, çevirme animasyonundaki hedef açı hesaplaması bu düzene göre
/// yapılır (bkz. daily_wheel_screen.dart _targetRotationFor).
class WheelPainter extends CustomPainter {
  final List<String> labels;

  const WheelPainter(this.labels);

  static const List<Color> sliceColors = [
    AppColors.gold,
    AppColors.doubleRiskNavy,
    AppColors.gold,
    AppColors.doubleRiskNavy,
    AppColors.gold,
    AppColors.doubleRiskNavy,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final sliceAngle = 2 * math.pi / labels.length;
    final rect = Rect.fromCircle(center: center, radius: radius - 2);

    for (int i = 0; i < labels.length; i++) {
      final startAngle = -math.pi / 2 + i * sliceAngle;
      final fillPaint = Paint()..color = sliceColors[i % sliceColors.length];
      canvas.drawArc(rect, startAngle, sliceAngle, true, fillPaint);

      final borderPaint = Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(rect, startAngle, sliceAngle, true, borderPaint);

      final labelAngle = startAngle + sliceAngle / 2;
      final labelRadius = radius * 0.62;
      final labelOffset = Offset(
        center.dx + labelRadius * math.cos(labelAngle),
        center.dy + labelRadius * math.sin(labelAngle),
      );

      final isGold = sliceColors[i % sliceColors.length] == AppColors.gold;
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: isGold ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(labelOffset.dx, labelOffset.dy);
      canvas.rotate(labelAngle + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    final outerBorder = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius - 2, outerBorder);
  }

  @override
  bool shouldRepaint(covariant WheelPainter oldDelegate) => oldDelegate.labels != labels;
}
