import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/cities.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../state/wallet_provider.dart';
import '../../state/workshop_provider.dart';

/// Her şehir için kazanılan parça ve sandık sayısını gösterir.
/// Bir şehirde galibiyet, o şehrin parçasını kazandırır (bkz.
/// game_table_screen.dart); yeterli parça biriktiğinde "Birleştir"
/// butonuyla bir sandığa dönüştürülebilir, sandıklar da "Aç" butonuyla
/// açılıp Risk Coin ödülü verir.
class WorkshopScreen extends ConsumerWidget {
  const WorkshopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workshop = ref.watch(workshopProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Atölye')),
      body: GradientBackground(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          scrollDirection: Axis.horizontal,
          itemCount: kCities.length,
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final city = kCities[index];
            final inventory = workshop.forCity(city.id);
            final canMerge = inventory.fragments >= kFragmentsPerChest;
            final canOpen = inventory.chests > 0;

            return Container(
              width: 240,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    city.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 14),

                  // Parçalar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (inventory.fragments % kFragmentsPerChest) / kFragmentsPerChest,
                      minHeight: 6,
                      color: AppColors.gold,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.extension, color: AppColors.gold, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${inventory.fragments}/$kFragmentsPerChest parça',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      PressableScale(
                        onTap: canMerge ? () => ref.read(workshopProvider.notifier).mergeFragments(city.id) : null,
                        child: _ActionButton(label: 'Birleştir', enabled: canMerge),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sandıklar
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2, color: AppColors.gold, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${inventory.chests} sandık',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      PressableScale(
                        onTap: canOpen
                            ? () {
                                final reward = ref.read(workshopProvider.notifier).openChest(city.id);
                                if (reward > 0) {
                                  ref.read(walletProvider.notifier).add(reward);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Sandıktan +$reward RC kazandın!')),
                                  );
                                }
                              }
                            : null,
                        child: _ActionButton(label: 'Aç', enabled: canOpen),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool enabled;

  const _ActionButton({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: enabled ? AppColors.gold : Colors.white12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: enabled ? Colors.black : Colors.white38,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
