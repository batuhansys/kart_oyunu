import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../state/level_provider.dart';

/// Gerçek ödeme entegrasyonu (in_app_purchase) sonradan bağlanacak -
/// mağazadaki gibi, şimdilik dokunma anında sunucu üzerinden (firebase-
/// admin ile) isRoyalPass=true yazılır. Aktif olunca leveling.js
/// otomatik olarak seviye atlama/kilometre taşı ödüllerini 2x yapar.
class RoyalPassScreen extends ConsumerStatefulWidget {
  const RoyalPassScreen({super.key});

  @override
  ConsumerState<RoyalPassScreen> createState() => _RoyalPassScreenState();
}

class _RoyalPassScreenState extends ConsumerState<RoyalPassScreen> {
  bool _isActivating = false;

  Future<void> _activate() async {
    setState(() => _isActivating = true);
    try {
      await ref.read(apiClientProvider).post('/api/royal-pass/activate');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Royal Pass etkinleştirildi!')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRoyalPass = ref.watch(levelProvider.select((s) => s.isRoyalPass));

    return Scaffold(
      appBar: AppBar(title: const Text('Royal Pass')),
      body: GradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium,
                size: 96,
                color: isRoyalPass ? AppColors.gold : Colors.white38,
              ),
              const SizedBox(height: 16),
              const Text(
                'Royal Pass ile seviye atlama ve kilometre taşı ödülleriniz '
                '2 katına çıkar, maksimum seviyede ekstra bonus kazanırsınız.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              if (isRoyalPass)
                const Text('Royal Pass zaten aktif', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold))
              else
                PressableScale(
                  onTap: _isActivating ? null : _activate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      _isActivating ? '...' : 'Royal Pass Satın Al',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
