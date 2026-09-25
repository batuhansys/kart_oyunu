import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/mp_history_entry.dart';
import '../../../domain/entities/player_choice.dart';

const double _kBadgeColumnWidth = 46;

/// Son oynanan elleri gosterir. "Sen" ve "Rakip" puan rozetleri sabit
/// genislikte iki ayri sutunda, ortalanmis olarak dizilir — boylece
/// farkli elerdeki ayni buyuklukteki degerler dikeyde ayni hizada durur.
class MpHistoryPanel extends StatelessWidget {
  final List<MpHistoryEntry> entries;

  const MpHistoryPanel({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('Henüz el oynanmadı', style: TextStyle(color: Colors.white54)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Expanded(child: SizedBox()),
              SizedBox(
                width: _kBadgeColumnWidth,
                child: Text('Sen', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 10)),
              ),
              SizedBox(
                width: _kBadgeColumnWidth,
                child: Text('Rakip', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 10)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
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
                            '${e.yourCard.rankLabel}${e.yourCard.suitSymbol} vs '
                            '${e.opponentCard.rankLabel}${e.opponentCard.suitSymbol}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        SizedBox(width: _kBadgeColumnWidth, child: Center(child: _scoreBadge(e.yourDelta))),
                        SizedBox(width: _kBadgeColumnWidth, child: Center(child: _scoreBadge(e.opponentDelta))),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sen: ${e.yourChoice.shortLabel}  •  Rakip: ${e.opponentChoice.shortLabel}',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
