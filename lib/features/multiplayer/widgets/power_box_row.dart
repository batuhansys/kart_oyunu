import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../state/multiplayer/multiplayer_notifier.dart';
import '../../../state/multiplayer/multiplayer_state.dart';
import '../../../state/power_provider.dart';

/// Oyun içi ZORBA/KALKAN/KAHİN kutucukları - geçmiş panelinin altında,
/// soldan sağa bu sırayla. Bir güç sahip değilse gri/tıklanamaz; sahipse
/// renkli + sağ üstte adet rozeti. Kullanınca (bkz. usePower) bu elde
/// başka güç kullanılamaz, ikonlar tekrar gri olur.
class PowerBoxRow extends ConsumerWidget {
  const PowerBoxRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(powerInventoryProvider);
    final mp = ref.watch(multiplayerProvider);

    final canUseAny = mp.stage == MpStage.playing && mp.usedPowerThisRound == null;

    ref.listen<MultiplayerState>(multiplayerProvider, (previous, next) {
      if (next.powerErrorMessage != null && next.powerErrorMessage != previous?.powerErrorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.powerErrorMessage!)));
        ref.read(multiplayerProvider.notifier).clearPowerError();
      }
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _PowerBox(
          icon: Icons.whatshot,
          label: 'ZORBA',
          count: inventory.zorba.usableCount,
          used: mp.usedPowerThisRound == 'zorba',
          enabled: canUseAny && inventory.zorba.usableCount > 0,
          onTap: () => ref.read(multiplayerProvider.notifier).usePower('zorba'),
        ),
        _PowerBox(
          icon: Icons.shield,
          label: 'KALKAN',
          count: inventory.kalkan.usableCount,
          used: mp.usedPowerThisRound == 'kalkan',
          enabled: canUseAny && inventory.kalkan.usableCount > 0,
          onTap: () => ref.read(multiplayerProvider.notifier).usePower('kalkan'),
        ),
        _PowerBox(
          icon: Icons.remove_red_eye,
          label: 'KAHİN',
          count: inventory.kahin.usableCount,
          used: mp.usedPowerThisRound == 'kahin',
          enabled: canUseAny && inventory.kahin.usableCount > 0,
          onTap: () => ref.read(multiplayerProvider.notifier).usePower('kahin'),
        ),
      ],
    );
  }
}

class _PowerBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool used;
  final bool enabled;
  final VoidCallback onTap;

  const _PowerBox({
    required this.icon,
    required this.label,
    required this.count,
    required this.used,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: used
                      ? AppColors.gold.withOpacity(0.25)
                      : enabled
                          ? AppColors.surfaceDark
                          : Colors.white10,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: enabled || used ? AppColors.gold : Colors.white24,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: enabled || used ? AppColors.gold : Colors.white24,
                ),
              ),
              if (count > 0 && !used)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.foldRed,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: enabled || used ? Colors.white70 : Colors.white24,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
