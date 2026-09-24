import '../../core/constants/score_table.dart';
import '../../domain/entities/player_choice.dart';
import '../../domain/entities/playing_card.dart';

class RoundResult {
  final int userScoreDelta;
  final int aiScoreDelta;
  const RoundResult({required this.userScoreDelta, required this.aiScoreDelta});
}

/// Bir elin puanlama mantığını uygular.
///
/// Kurallar (kaynak dokümandan):
/// - Pas geçen oyuncu o elden puan almaz/kaybetmez.
/// - 2 ve A blöf kartlarıdır: bu kartı elinde tutan oyuncu için sonuç
///   HER ZAMAN puansızdır (2 asla kaybettirmez, A asla kazandırmaz),
///   tıpkı pas geçilmiş gibi. Ancak rakibin bu kart sahibine karşı
///   yaptığı risk, kartların gerçek değerine göre değerlendirilir.
/// - Riske giren oyuncu kartı rakibinden yüksekse kazanç, eşit/düşükse
///   ceza puanı alır.
/// - Çifte Riske Gir: kazanç/kayıp puanı 2 ile çarpılır.
/// - İki oyuncunun puanı birbirinden bağımsız hesaplanır.
class ScoringService {
  ScoringService._();

  static int _scoreForPlayer({
    required PlayingCard ownCard,
    required PlayingCard opponentCard,
    required PlayerChoice choice,
  }) {
    if (choice == PlayerChoice.pass) return 0;
    if (ownCard.isBluffCard) return 0;

    final entry = kScoreTable[ownCard.rank]!;
    final won = ownCard.rank > opponentCard.rank;

    if (choice == PlayerChoice.timeout) {
      // Zaman aşımı: kazanan kart olsa dahi puan getirmez; kaybeden
      // kartsa çifte riskin ceza puanını alır.
      return won ? 0 : entry.lose * 2;
    }

    final base = won ? entry.win : entry.lose;
    final multiplier = choice == PlayerChoice.doubleRisk ? 2 : 1;
    return base * multiplier;
  }

  static RoundResult calculate({
    required PlayingCard userCard,
    required PlayerChoice userChoice,
    required PlayingCard aiCard,
    required PlayerChoice aiChoice,
  }) {
    final userDelta = _scoreForPlayer(
      ownCard: userCard,
      opponentCard: aiCard,
      choice: userChoice,
    );
    final aiDelta = _scoreForPlayer(
      ownCard: aiCard,
      opponentCard: userCard,
      choice: aiChoice,
    );
    return RoundResult(userScoreDelta: userDelta, aiScoreDelta: aiDelta);
  }
}
