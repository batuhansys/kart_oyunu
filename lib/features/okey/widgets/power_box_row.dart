import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../state/multiplayer/multiplayer_notifier.dart';
import '../../../state/power_provider.dart';

/// Oyun ici ZORBA/KALKAN/KAHIN kutulari. Sahip olunmayan/su an kullanilamayan
/// gri; kullanilabilir olan renkli + adet rozetli. Bir elde en fazla 1 guc.
///  - ZORBA: siradaki oyuncunun turunu atlatir.
///  - KALKAN: bu el ceza puaninin yarisini siler.
///  - KAHIN: destenin ustundeki tasi gosterir.
class PowerBoxRow extends ConsumerWidget {
  final bool canUse;
  final String? usedPower;

  const PowerBoxRow({super.key, required this.canUse, required this.usedPower});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(powerInventoryProvider);
    final notifier = ref.read(multiplayerProvider.notifier);

    Widget box(String key, IconData icon, String label, String tip, int count) {
      final enabled = canUse && usedPower == null && count > 0;
      final used = usedPower == key;
      return Tooltip(
        message: tip,
        child: GestureDetector(
          onTap: enabled ? () => notifier.usePower(key) : null,
          onLongPress: () => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$label: $tip'))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: used
                        ? AppColors.gold.withOpacity(0.3)
                        : enabled
                            ? AppColors.surfaceDark
                            : Colors.white10,
                    shape: BoxShape.circle,
                    border: Border.all(color: enabled || used ? AppColors.gold : Colors.white24, width: 2),
                  ),
                  child: Icon(icon, size: 17, color: enabled || used ? AppColors.gold : Colors.white24),
                ),
                if (count > 0 && !used)
                  Positioned(
                    top: -4,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.foldRed,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        box('zorba', Icons.whatshot, 'ZORBA', 'Sıradaki oyuncunun turunu atlatır', inv.zorba.usableCount),
        box('kalkan', Icons.shield, 'KALKAN', 'Bu el ceza puanının yarısını siler', inv.kalkan.usableCount),
        box('kahin', Icons.remove_red_eye, 'KAHİN', 'Destenin üstündeki taşı gösterir', inv.kahin.usableCount),
      ],
    );
  }
}
