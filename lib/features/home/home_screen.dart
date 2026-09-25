import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_rc_counter.dart';
import '../../core/widgets/gradient_background.dart';
import '../../state/auth_provider.dart';
import '../../state/wallet_provider.dart';
import 'widgets/menu_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider.select((s) => s.profile));
    final riskCoin = ref.watch(walletProvider.select((s) => s.riskCoin));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.mail_outline),
          onPressed: () => context.push('/notifications'),
        ),
        title: Text(
          'RİSK',
          style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Text('Lv.${profile?.level ?? 1}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => context.push('/account'),
                  child: const CircleAvatar(child: Icon(Icons.person)),
                ),
              ],
            ),
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on, color: AppColors.gold),
                      const SizedBox(width: 6),
                      AnimatedRcCounter(
                        value: riskCoin,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: AppColors.doubleRiskNavy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: const Icon(Icons.workspace_premium, color: AppColors.gold),
                      title: const Text('Royal Pass', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Ödülleri katla!', style: TextStyle(color: Colors.white70)),
                      onTap: () => context.push('/royal-pass'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    MenuButton(label: 'Arkadaşlar', icon: Icons.people, onTap: () => context.push('/friends')),
                    MenuButton(
                      label: 'Oyna',
                      icon: Icons.play_arrow,
                      big: true,
                      onTap: () => context.push('/multiplayer'),
                    ),
                    MenuButton(label: 'Mağaza', icon: Icons.store, onTap: () => context.push('/shop')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    MenuButton(label: 'Günlük Çark', icon: Icons.casino, onTap: () => context.push('/daily-wheel')),
                    MenuButton(label: 'Atölye', icon: Icons.build, onTap: () => context.push('/workshop')),
                    MenuButton(label: 'Ayarlar', icon: Icons.settings, onTap: () => context.push('/settings')),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
