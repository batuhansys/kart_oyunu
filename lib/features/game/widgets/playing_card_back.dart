import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Kartın kapalı (arka) yüzü: altın kenarlıklı, lacivert degradeli ve
/// üzerinde ince bir baklava deseni olan casino tarzı bir tasarım.
/// Tamamen CustomPaint ile çizilir, dış görsel dosyası gerekmez.
class PlayingCardBack extends StatelessWidget {
  const PlayingCardBack({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.doubleRiskNavy, Color(0xFF0D1B4C)],
        ),
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _LatticePainter(),
          child: const Center(
            child: Icon(Icons.diamond, color: AppColors.gold, size: 26),
          ),
        ),
      ),
    );
  }
}

class _LatticePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withOpacity(0.22)
      ..strokeWidth = 1;

    const step = 14.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
      canvas.drawLine(Offset(x + size.height, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LatticePainter oldDelegate) => false;
}
