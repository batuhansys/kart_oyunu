import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../state/sound_provider.dart';
import '../../state/wallet_provider.dart';

/// NOT: Kaynak dokümanda iki farklı mağaza paket listesi vardı (biri
/// fiyatsız RC listesi, diğeri $ fiyatlı liste). Burada fiyatsız liste
/// esas alınmıştır. Gerçek satın alma için Google Play Billing
/// entegrasyonu (`in_app_purchase` paketi + gerçek bir
/// `EconomyRepository` implementasyonu) eklenmelidir; şu an
/// `LocalEconomyRepository` gerçek para almadan RC'yi doğrudan ekliyor
/// (bkz. lib/data/repositories/local_economy_repository.dart).
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  static const List<int> packages = [1000, 5000, 25000, 100000, 500000, 2500000];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mağaza')),
      body: GradientBackground(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Tüm paketler tek satırda, ekrana sığacak şekilde yatay
              // dizilir; paket sayısı arttığında yatay kaydırma devreye
              // girer.
              final itemWidth = (constraints.maxWidth - 16 * 2 - 12 * (packages.length - 1)) /
                  packages.length.clamp(1, 4);
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                scrollDirection: Axis.horizontal,
                itemCount: packages.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final amount = packages[index];
                  return SizedBox(
                    width: itemWidth.clamp(120, 220),
                    child: PressableScale(
                      onTap: wallet.isPurchasing
                          ? null
                          : () async {
                              await ref.read(walletProvider.notifier).purchasePackage(amount);
                              if (!context.mounted) return;
                              final error = ref.read(walletProvider).errorMessage;
                              if (error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                              } else {
                                ref.read(soundServiceProvider).playCoin();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Risk Coin satın alındı')),
                                );
                              }
                            },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.gold.withOpacity(0.35)),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.monetization_on, color: AppColors.gold, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                '$amount RC',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
