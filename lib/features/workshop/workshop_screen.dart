import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/cities.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../state/power_provider.dart';
import '../../state/workshop_provider.dart';

String _formatRemaining(Duration? d) {
  if (d == null) return '-';
  if (d.inDays >= 1) return '${d.inDays} gün ${d.inHours % 24} sa';
  if (d.inHours >= 1) return '${d.inHours} sa ${d.inMinutes % 60} dk';
  return '${d.inMinutes} dk';
}

String _powerLabel(String power) {
  switch (power) {
    case 'zorba':
      return 'ZORBA';
    case 'kalkan':
      return 'KALKAN';
    case 'kahin':
      return 'KAHİN';
    default:
      return power;
  }
}

IconData _powerIcon(String power) {
  switch (power) {
    case 'zorba':
      return Icons.whatshot;
    case 'kalkan':
      return Icons.shield;
    case 'kahin':
      return Icons.remove_red_eye;
    default:
      return Icons.help_outline;
  }
}

/// Her şehir için kazanılan parça ve sandık sayısını gösterir (sadece
/// şehir kuyruğu maçı kazanınca parça kazanılır, bkz. server/game/room.js).
/// Yeterli parça biriktiğinde "Birleştir" butonuyla bir sandığa dönüşür;
/// sandıklar "Aç" butonuyla açılıp RC veya ZORBA/KALKAN/KAHİN ödülü verir.
class WorkshopScreen extends ConsumerWidget {
  const WorkshopScreen({super.key});

  Future<void> _handleOpenChest(BuildContext context, WidgetRef ref, String cityId) async {
    final result = await ref.read(workshopProvider.notifier).openChest(cityId);
    if (!context.mounted) return;
    if (result == null) {
      final error = ref.read(workshopProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    final String message;
    final IconData icon;
    if (result.rewardType == 'rc') {
      message = '+${result.rc} RC kazandın!';
      icon = Icons.monetization_on;
    } else {
      message = '${_powerLabel(result.power!)} gücü kazandın!';
      icon = _powerIcon(result.power!);
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Sandık Açıldı!', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.gold, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Harika!'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workshop = ref.watch(workshopProvider);
    final powers = ref.watch(powerInventoryProvider);

    ref.listen(workshopProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Atölye')),
      body: GradientBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Güç Envanterin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _powerRow('zorba', powers.zorba),
                    _powerRow('kalkan', powers.kalkan),
                    _powerRow('kahin', powers.kahin),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                scrollDirection: Axis.horizontal,
                itemCount: kCities.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final city = kCities[index];
                  final inventory = workshop.forCity(city.id);
                  final canMerge = inventory.fragments >= kFragmentsPerChest;
                  final canOpen = inventory.chests > 0 && !workshop.isBusy;

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
                                    '${inventory.fragments}/$kMaxFragmentsPerCity parça',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            PressableScale(
                              onTap: canMerge && !workshop.isBusy
                                  ? () => ref.read(workshopProvider.notifier).mergeFragments(city.id)
                                  : null,
                              child: _ActionButton(label: 'Birleştir', enabled: canMerge && !workshop.isBusy),
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
                              onTap: canOpen ? () => _handleOpenChest(context, ref, city.id) : null,
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
          ],
        ),
      ),
    );
  }

  Widget _powerRow(String power, PowerCount count) {
    final usable = count.usableCount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(_powerIcon(power), color: usable > 0 ? AppColors.gold : Colors.white24, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              _powerLabel(power),
              style: TextStyle(color: usable > 0 ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '×$usable',
            style: TextStyle(color: usable > 0 ? AppColors.gold : Colors.white38, fontWeight: FontWeight.bold),
          ),
          if (usable > 0) ...[
            const SizedBox(width: 10),
            Text(
              'kalan: ${_formatRemaining(count.remaining)}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ],
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
