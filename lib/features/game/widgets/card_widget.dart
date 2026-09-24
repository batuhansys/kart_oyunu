import 'package:flutter/material.dart';

import '../../../data/models/playing_card.dart';
import 'timer_frame_painter.dart';

/// Bir kartı (açık veya kapalı) ve isteğe bağlı olarak etrafındaki
/// zamanlayıcı/tercih çerçevesini çizer.
class CardWidget extends StatelessWidget {
  final PlayingCard? card; // null: kapalı/bilinmeyen kart
  final bool faceDown;
  final double? timerProgress; // 0.0-1.0, null ise zamanlayıcı yok
  final Color? frameColor; // tercih yapıldıysa sabit renk

  const CardWidget({
    super.key,
    required this.card,
    this.faceDown = false,
    this.timerProgress,
    this.frameColor,
  });

  @override
  Widget build(BuildContext context) {
    final isRed =
        card != null && (card!.suit == Suit.hearts || card!.suit == Suit.diamonds);

    return SizedBox(
      width: 90,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (timerProgress != null || frameColor != null)
            Positioned.fill(
              child: CustomPaint(
                painter: TimerFramePainter(
                  progress: timerProgress ?? 0,
                  overrideColor: frameColor,
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: faceDown || card == null ? const Color(0xFF1A237E) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
            ),
            child: faceDown || card == null
                ? const Center(
                    child: Icon(Icons.casino, color: Color(0xFFD4AF37), size: 28),
                  )
                : Center(
                    child: Text(
                      '${card!.rankLabel}${card!.suitSymbol}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isRed ? Colors.red : Colors.black,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
