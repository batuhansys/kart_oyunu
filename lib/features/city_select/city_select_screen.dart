import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/cities.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../state/wallet_provider.dart';

class CitySelectScreen extends ConsumerWidget {
  const CitySelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Şehir Seç')),
      body: GradientBackground(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          scrollDirection: Axis.horizontal,
          itemCount: kCities.length,
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final city = kCities[index];
            final canAfford = wallet.riskCoin >= city.entryFee;

            return SizedBox(
              width: 220,
              child: PressableScale(
                onTap: canAfford
                    ? () {
                        ref.read(walletProvider.notifier).deduct(city.entryFee);
                        context.push('/game', extra: city);
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: canAfford ? AppColors.gold.withOpacity(0.4) : Colors.white12),
                    boxShadow: canAfford
                        ? [BoxShadow(color: AppColors.gold.withOpacity(0.15), blurRadius: 8)]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        city.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Giriş: ${city.entryFee} RC',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      Text(
                        'Kazanç: ${city.rewardAmount} RC',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: canAfford ? AppColors.gold : Colors.white12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            canAfford ? 'Gir' : 'Yetersiz',
                            style: TextStyle(
                              color: canAfford ? Colors.black : Colors.white38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
