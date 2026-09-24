import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/entities/playing_card.dart';
import 'playing_card_back.dart';
import 'playing_card_face.dart';

/// Kartın kapalıdan açığa (veya tersi) 3 boyutlu bir çevirme
/// animasyonuyla geçmesini sağlar. `showFace` true olduğunda ön yüz
/// (kartın kendisi), false olduğunda arka yüz (kapalı kart deseni)
/// gösterilir; değer değiştiğinde otomatik olarak çevirme animasyonu
/// oynatılır.
class FlippableCard extends StatefulWidget {
  final PlayingCard card;
  final bool showFace;

  const FlippableCard({super.key, required this.card, required this.showFace});

  @override
  State<FlippableCard> createState() => _FlippableCardState();
}

class _FlippableCardState extends State<FlippableCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late PlayingCard _displayedCard;

  @override
  void initState() {
    super.initState();
    _displayedCard = widget.card;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: widget.showFace ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant FlippableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showFace != widget.showFace) {
      if (widget.showFace) {
        // Açılırken: yeni kartı hemen göster, ön yüz dönerek ortaya çıkacak.
        _displayedCard = widget.card;
        _controller.forward();
      } else {
        // Kapanırken: eski kart, arkası tamamen dönene kadar ekranda
        // kalmalı; aksi halde bir sonraki elin kartı erken (spoiler
        // olarak) görünür.
        _controller.reverse().whenCompleteOrCancel(() {
          if (mounted) {
            setState(() => _displayedCard = widget.card);
          }
        });
      }
    } else if (widget.card != oldWidget.card) {
      // showFace değişmeden kart değiştiyse (örn. kullanıcının kartı,
      // sürekli açık olduğu için hiç çevrilmez): çevirme animasyonu
      // tetiklenmeyeceğinden burada elle setState ile güncelliyoruz.
      setState(() => _displayedCard = widget.card);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * pi;
        final showingFace = _controller.value > 0.5;
        // Kart 90 dereceyi geçince yüzü değiştiriyoruz; bu sırada ters
        // görünmemesi için açıyı pi kadar geri alıyoruz (ayna etkisi).
        final displayAngle = showingFace ? angle - pi : angle;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(displayAngle),
          child: showingFace ? PlayingCardFace(card: _displayedCard) : const PlayingCardBack(),
        );
      },
    );
  }
}
