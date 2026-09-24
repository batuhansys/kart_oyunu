import 'package:flutter/material.dart';

import '../../../domain/entities/playing_card.dart';
import 'flippable_card.dart';
import 'timer_ring_painter.dart';

/// Bir oyuncunun kart alanını (kart + üzerindeki zamanlayıcı/tercih
/// halkası) bir araya getirir.
class CardSlot extends StatelessWidget {
  final PlayingCard card;
  final bool showFace;
  final double? timerProgress;
  final Color? frameColor;

  const CardSlot({
    super.key,
    required this.card,
    required this.showFace,
    this.timerProgress,
    this.frameColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 136,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (timerProgress != null || frameColor != null)
            Positioned.fill(
              child: CustomPaint(
                painter: TimerRingPainter(progress: timerProgress ?? 0, overrideColor: frameColor),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: FlippableCard(card: card, showFace: showFace),
          ),
        ],
      ),
    );
  }
}
