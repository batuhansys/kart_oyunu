import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Uygulama genelinde kullanılan koyu, casino esintili degrade arka
/// plan. Farklı ekranlar (menü, oyun masası) kendi gradyanını
/// verebilir; verilmezse varsayılan koyu yeşil/siyah degrade kullanılır.
class GradientBackground extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;

  const GradientBackground({super.key, required this.child, this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ??
            const RadialGradient(
              center: Alignment.topCenter,
              radius: 1.4,
              colors: [Color(0xFF0F3D28), AppColors.feltGreenDark],
            ),
      ),
      child: child,
    );
  }
}
