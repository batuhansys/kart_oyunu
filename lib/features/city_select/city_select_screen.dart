import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/city_list_view.dart';
import '../../core/widgets/gradient_background.dart';
import '../../state/wallet_provider.dart';

class CitySelectScreen extends ConsumerWidget {
  const CitySelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Şehir Seç')),
      body: GradientBackground(
        child: CityListView(
          riskCoin: wallet.riskCoin,
          onSelect: (city) {
            ref.read(walletProvider.notifier).deduct(city.entryFee);
            context.push('/game', extra: city);
          },
        ),
      ),
    );
  }
}
