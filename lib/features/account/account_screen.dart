import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_rc_counter.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../state/auth_provider.dart';
import '../../state/wallet_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider.select((s) => s.profile));
    final riskCoin = ref.watch(walletProvider.select((s) => s.riskCoin));

    return Scaffold(
      appBar: AppBar(title: const Text('Hesabım')),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const CircleAvatar(radius: 48, backgroundColor: AppColors.surfaceDark, child: Icon(Icons.person, size: 48, color: AppColors.gold)),
                const SizedBox(height: 16),
                Text(
                  profile?.username ?? '-',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text('ID: ${profile?.userId ?? '-'}', style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                Text(
                  'Seviye: ${profile?.level ?? 1}   XP: ${profile?.xp ?? 0}',
                  style: const TextStyle(color: Colors.white70),
                ),
                AnimatedRcCounter(
                  value: riskCoin,
                  style: const TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                PressableScale(
                  onTap: () {
                    ref.read(authProvider.notifier).logout();
                    context.go('/login');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white38),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
