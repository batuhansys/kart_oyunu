import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/playing_card.dart';

/// Bir kartın ön yüzünü tamamen vektörel (Text + Stack) olarak çizer.
/// Herhangi bir görsel dosyaya ihtiyaç duymaz, bu yüzden her çözünürlükte
/// keskin görünür ve ek asset yönetimi gerektirmez.
class PlayingCardFace extends StatelessWidget {
  final PlayingCard card;
  const PlayingCardFace({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final isRed = card.suit == Suit.hearts || card.suit == Suit.diamonds;
    final color = isRed ? AppColors.cardRed : AppColors.cardBlack;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Stack(
        children: [
          Positioned(top: 6, left: 8, child: _CornerLabel(card: card, color: color)),
          Center(
            child: Text(
              card.suitSymbol,
              style: TextStyle(fontSize: 38, color: color.withOpacity(0.85), height: 1),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 8,
            child: Transform.rotate(
              angle: 3.14159,
              child: _CornerLabel(card: card, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerLabel extends StatelessWidget {
  final PlayingCard card;
  final Color color;
  const _CornerLabel({required this.card, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          card.rankLabel,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color, height: 1),
        ),
        Text(card.suitSymbol, style: TextStyle(fontSize: 13, color: color, height: 1.1)),
      ],
    );
  }
}
