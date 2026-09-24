import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Kazanma oranını gösteren halka (donut) grafik. Ortasında yüzdeyi,
/// altında kazanılan/kaybedilen/berabere sayısını gösterir.
class WinRateChart extends StatelessWidget {
  final int wins;
  final int losses;
  final int draws;

  const WinRateChart({
    super.key,
    required this.wins,
    required this.losses,
    required this.draws,
  });

  @override
  Widget build(BuildContext context) {
    final total = wins + losses + draws;
    final winRate = total == 0 ? 0.0 : wins / total;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) {
              return CustomPaint(
                painter: _WinRateDonutPainter(
                  wins: wins,
                  losses: losses,
                  draws: draws,
                  progress: t,
                ),
                child: Center(
                  child: Text(
                    total == 0 ? '-' : '${(winRate * t * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: AppColors.riskBlue, label: 'Galibiyet: $wins'),
            const SizedBox(width: 12),
            _LegendDot(color: AppColors.foldRed, label: 'Mağlubiyet: $losses'),
            const SizedBox(width: 12),
            _LegendDot(color: AppColors.passGray, label: 'Berabere: $draws'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _WinRateDonutPainter extends CustomPainter {
  final int wins;
  final int losses;
  final int draws;
  final double progress;

  _WinRateDonutPainter({
    required this.wins,
    required this.losses,
    required this.draws,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) / 2;
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final track = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, track);

    final total = wins + losses + draws;
    if (total == 0) return;

    final winSweep = 2 * pi * (wins / total) * progress;
    final lossSweep = 2 * pi * (losses / total) * progress;

    final winPaint = Paint()
      ..color = AppColors.riskBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, winSweep, false, winPaint);

    final lossPaint = Paint()
      ..color = AppColors.foldRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2 + winSweep, lossSweep, false, lossPaint);
  }

  @override
  bool shouldRepaint(covariant _WinRateDonutPainter oldDelegate) {
    return oldDelegate.wins != wins ||
        oldDelegate.losses != losses ||
        oldDelegate.draws != draws ||
        oldDelegate.progress != progress;
  }
}
