import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../state/level_provider.dart';

class LevelRewardsScreen extends ConsumerWidget {
  const LevelRewardsScreen({super.key});

  String _kindLabel(String kind) {
    switch (kind) {
      case 'milestone':
        return 'Kilometre Taşı';
      case 'maxlevel':
        return 'Maksimum Seviye';
      default:
        return 'Seviye Atlama';
    }
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'milestone':
        return Icons.emoji_events;
      case 'maxlevel':
        return Icons.workspace_premium;
      default:
        return Icons.arrow_circle_up;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(levelProvider);
    final totalRc = level.pendingRewards.fold<int>(0, (sum, r) => sum + r.rc);

    ref.listen(levelProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Seviye Ödülleri')),
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Seviye ${level.level}',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        if (level.isRoyalPass) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.workspace_premium, color: AppColors.gold, size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (level.isMaxLevel)
                      const Text('Maksimum seviyeye ulaştın!', style: TextStyle(color: AppColors.gold))
                    else ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: level.progress,
                          minHeight: 10,
                          backgroundColor: AppColors.surfaceDark,
                          valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${level.xp} / ${level.xpNeededForNext} XP',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: level.pendingRewards.isEmpty
                    ? const Center(
                        child: Text('Bekleyen ödül yok.', style: TextStyle(color: Colors.white70)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: level.pendingRewards.length,
                        itemBuilder: (context, index) {
                          final reward = level.pendingRewards[index];
                          return Card(
                            color: AppColors.surfaceDark,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Icon(_kindIcon(reward.kind), color: AppColors.gold),
                              title: Text(
                                '${_kindLabel(reward.kind)} · Seviye ${reward.level}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              trailing: Text(
                                '+${reward.rc} RC',
                                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: PressableScale(
                  onTap: level.pendingRewards.isEmpty || level.isClaiming
                      ? null
                      : () => ref.read(levelProvider.notifier).claimRewards(),
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: level.pendingRewards.isEmpty ? AppColors.gold.withOpacity(0.3) : AppColors.gold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      level.isClaiming
                          ? '...'
                          : level.pendingRewards.isEmpty
                              ? 'Toplanacak Ödül Yok'
                              : 'Tümünü Topla (+$totalRc RC)',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
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
