import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/pressable_scale.dart';

/// TODO: gerçek satın alma akışı (in_app_purchase) ve seviye atlama
/// ödül çarpanı mantığı eklenmelidir.
class RoyalPassScreen extends StatelessWidget {
  const RoyalPassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Royal Pass')),
      body: GradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium, size: 96, color: AppColors.gold),
              const SizedBox(height: 16),
              const Text(
                'Royal Pass ile seviye atlama ödülleriniz katlanır ve '
                'her 3 seviyede 1 yerine 3 sandık parçası kazanırsınız.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              PressableScale(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Royal Pass Satın Al', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
