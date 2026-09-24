import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/game_history_entry.dart';
import '../../../domain/entities/player_choice.dart';

/// Sağ panelde son 10 elin sonuçlarını, renkli puan rozetleriyle
/// birlikte listeler.
class HistoryPanel extends StatelessWidget {
  final List<GameHistoryEntry> entries;

  const HistoryPanel({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('Henüz el oynanmadı', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${e.userCard.rankLabel}${e.userCard.suitSymbol} vs ${e.aiCard.rankLabel}${e.aiCard.suitSymbol}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  _scoreBadge(e.userDelta),
                  const SizedBox(width: 4),
                  _scoreBadge(e.aiDelta),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Sen: ${e.userChoice.shortLabel}  •  Rakip: ${e.aiChoice.shortLabel}',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _scoreBadge(int delta) {
    final color = delta > 0
        ? Colors.greenAccent
        : (delta < 0 ? AppColors.foldRed : Colors.white38);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(
        '${delta >= 0 ? '+' : ''}$delta',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
