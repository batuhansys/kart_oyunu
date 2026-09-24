import 'dart:math';

import '../../core/constants/game_constants.dart';
import '../../domain/entities/player_choice.dart';
import '../../domain/entities/playing_card.dart';

/// Yapay zekanın kendi kartına göre risk kararını simüle eder.
///
/// Basit bir heuristik kullanılır: kart değeri yükseldikçe riske girme
/// olasılığı artar; blöf kartlarında (2, A) davranış biraz karıştırılır
/// ki AI'nın tercihi kartın gerçek değerinden %100 tahmin edilebilir
/// olmasın. Bu, gerçek bir oyun dengeleme sürecinden geçmemiştir; beta
/// test sırasında zorluk seviyesine göre ayarlanması önerilir.
class AiDecisionService {
  AiDecisionService._();

  static final Random _random = Random();

  static PlayerChoice decide({
    required PlayingCard aiCard,
    required int consecutivePasses,
  }) {
    if (consecutivePasses >= kMaxConsecutivePasses) {
      return _decideRiskLevel(aiCard);
    }

    final normalizedStrength = (aiCard.rank - 2) / 12.0;
    final bluffNoise = aiCard.isBluffCard ? (_random.nextDouble() * 0.3 - 0.15) : 0.0;
    final riskProbability =
        (0.15 + normalizedStrength * 0.7 + bluffNoise).clamp(0.05, 0.95);

    if (_random.nextDouble() > riskProbability) {
      return PlayerChoice.pass;
    }
    return _decideRiskLevel(aiCard);
  }

  static PlayerChoice _decideRiskLevel(PlayingCard aiCard) {
    if (aiCard.rank >= 11 && _random.nextDouble() < 0.35) {
      return PlayerChoice.doubleRisk;
    }
    return PlayerChoice.risk;
  }
}
