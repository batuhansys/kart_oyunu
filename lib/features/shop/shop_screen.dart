import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../state/sound_provider.dart';
import '../../state/wallet_provider.dart';

/// Mağaza paketi: miktar + pazarlama ismi. İsimler miktara göre
/// kademelenir (büyüdükçe daha "prestijli" bir isim alır).
///
/// NOT: Gerçek satın alma için Google Play Billing entegrasyonu
/// (`in_app_purchase` paketi + gerçek bir `EconomyRepository`
/// implementasyonu) sonradan bağlanacak; şu an dokunma anında RC'yi
/// doğrudan sunucu üzerinden (bkz. FirebaseEconomyRepository) ekliyoruz.
class ShopPackage {
  final int amount;
  final String name;
  const ShopPackage(this.amount, this.name);
}

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  static const List<ShopPackage> packages = [
    ShopPackage(1000, 'Başlangıç Kesesi'),
    ShopPackage(5000, 'Gümüş Kese'),
    ShopPackage(25000, 'Altın Kese'),
    ShopPackage(100000, 'Elmas Sandık'),
    ShopPackage(500000, 'İmparatorluk Hazinesi'),
    ShopPackage(2500000, 'Kraliyet Hazinesi'),
  ];

  static String _formatRc(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mağaza')),
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Yatay ekranda 3, dar ekranlarda 2 sutun - her paket
                // ekrana orantili, kare-ye yakin bir kart olarak sigar.
                final columns = constraints.maxWidth > 700 ? 3 : 2;
                return GridView.builder(
                  itemCount: packages.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    final pkg = packages[index];
                    return _PackageCard(
                      package: pkg,
                      isPurchasing: wallet.isPurchasing,
                      formattedAmount: _formatRc(pkg.amount),
                      onTap: wallet.isPurchasing
                          ? null
                          : () async {
                              await ref.read(walletProvider.notifier).purchasePackage(pkg.amount);
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
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final ShopPackage package;
  final String formattedAmount;
  final bool isPurchasing;
  final VoidCallback? onTap;

  const _PackageCard({
    required this.package,
    required this.formattedAmount,
    required this.isPurchasing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withOpacity(0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.monetization_on, color: AppColors.gold, size: 32),
            const SizedBox(height: 8),
            Text(
              package.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '$formattedAmount RC',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: onTap == null ? AppColors.gold.withOpacity(0.3) : AppColors.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isPurchasing ? '...' : 'Satın Al',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
