import 'package:flutter/material.dart';

import '../../core/constants/cities.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../domain/entities/game_city.dart';

/// Şehir seçim kartlarını yatay (veya dikey) bir listede gösterir.
/// Çok oyunculu lobi (lib/features/multiplayer/multiplayer_lobby_screen.dart)
/// ve "Oda Kur" şehir seçim adımı gibi birden fazla akışta aynı görsel
/// dille kullanılır; ne olacağına (kuyruğa katıl, oda kur vb.) [onSelect]
/// karar verir.
class CityListView extends StatelessWidget {
  final int riskCoin;
  final void Function(GameCity city) onSelect;
  final Axis scrollDirection;

  const CityListView({
    super.key,
    required this.riskCoin,
    required this.onSelect,
    this.scrollDirection = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      scrollDirection: scrollDirection,
      itemCount: kCities.length,
      separatorBuilder: (context, index) => const SizedBox(width: 12, height: 12),
      itemBuilder: (context, index) {
        final city = kCities[index];
        final canAfford = riskCoin >= city.entryFee;

        final card = PressableScale(
          onTap: canAfford ? () => onSelect(city) : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: canAfford ? AppColors.gold.withOpacity(0.4) : Colors.white12),
              boxShadow: canAfford
                  ? [BoxShadow(color: AppColors.gold.withOpacity(0.15), blurRadius: 8)]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  city.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Giriş: ${city.entryFee} RC',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                Text(
                  'Kazanç: ${city.rewardAmount} RC',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: canAfford ? AppColors.gold : Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      canAfford ? 'Gir' : 'Yetersiz',
                      style: TextStyle(
                        color: canAfford ? Colors.black : Colors.white38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        // Yatayda sabit genislikte kartlar (tek oyunculu ekran); dikeyde
        // (cok oyunculu lobi paneli) kart genisligi kolonu doldurur, kart
        // sadece kendi icerigi kadar yukseklik alir (MainAxisSize.min).
        return scrollDirection == Axis.horizontal ? SizedBox(width: 220, child: card) : card;
      },
    );
  }
}
