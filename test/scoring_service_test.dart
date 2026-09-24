import 'package:flutter_test/flutter_test.dart';
import 'package:risk_get_and_gain/domain/entities/player_choice.dart';
import 'package:risk_get_and_gain/domain/entities/playing_card.dart';
import 'package:risk_get_and_gain/state/game/scoring_service.dart';

void main() {
  group('ScoringService - kaynak dokümandaki senaryolar', () {
    test('Senaryo 1: kullanıcı 2, rakip J, ikisi de riske girer', () {
      final result = ScoringService.calculate(
        userCard: const PlayingCard(suit: Suit.spades, rank: 2),
        userChoice: PlayerChoice.risk,
        aiCard: const PlayingCard(suit: Suit.hearts, rank: 11),
        aiChoice: PlayerChoice.risk,
      );
      expect(result.userScoreDelta, 0);
      expect(result.aiScoreDelta, 40);
    });

    test('Senaryo 2: kullanıcı 2 ile riske girer, rakip pas geçer', () {
      final result = ScoringService.calculate(
        userCard: const PlayingCard(suit: Suit.spades, rank: 2),
        userChoice: PlayerChoice.risk,
        aiCard: const PlayingCard(suit: Suit.hearts, rank: 11),
        aiChoice: PlayerChoice.pass,
      );
      expect(result.userScoreDelta, 0);
      expect(result.aiScoreDelta, 0);
    });

    test('Senaryo 3: kullanıcı 10, rakip A, ikisi de riske girer', () {
      final result = ScoringService.calculate(
        userCard: const PlayingCard(suit: Suit.spades, rank: 10),
        userChoice: PlayerChoice.risk,
        aiCard: const PlayingCard(suit: Suit.hearts, rank: 14),
        aiChoice: PlayerChoice.risk,
      );
      expect(result.userScoreDelta, -80);
      expect(result.aiScoreDelta, 0);
    });

    test('Senaryo 4: eşit kartlar (2-2) puansız sonuçlanır', () {
      final result = ScoringService.calculate(
        userCard: const PlayingCard(suit: Suit.spades, rank: 2),
        userChoice: PlayerChoice.risk,
        aiCard: const PlayingCard(suit: Suit.hearts, rank: 2),
        aiChoice: PlayerChoice.risk,
      );
      expect(result.userScoreDelta, 0);
      expect(result.aiScoreDelta, 0);
    });

    test('Senaryo 4b: eşit kartlar (A-A) puansız sonuçlanır', () {
      final result = ScoringService.calculate(
        userCard: const PlayingCard(suit: Suit.spades, rank: 14),
        userChoice: PlayerChoice.risk,
        aiCard: const PlayingCard(suit: Suit.hearts, rank: 14),
        aiChoice: PlayerChoice.risk,
      );
      expect(result.userScoreDelta, 0);
      expect(result.aiScoreDelta, 0);
    });

    test('Senaryo 5: kullanıcı 7 rakip 5, ikisi de riske girer', () {
      final result = ScoringService.calculate(
        userCard: const PlayingCard(suit: Suit.spades, rank: 7),
        userChoice: PlayerChoice.risk,
        aiCard: const PlayingCard(suit: Suit.hearts, rank: 5),
        aiChoice: PlayerChoice.risk,
      );
      expect(result.userScoreDelta, 50);
      // score_table.dart'ta 5 kartinin kayip puani -40'tir (4,5,6 grubu).
      expect(result.aiScoreDelta, -40);
    });

    test('Pas geçen oyuncu hiçbir zaman puan almaz/kaybetmez', () {
      final result = ScoringService.calculate(
        userCard: const PlayingCard(suit: Suit.spades, rank: 13),
        userChoice: PlayerChoice.pass,
        aiCard: const PlayingCard(suit: Suit.hearts, rank: 3),
        aiChoice: PlayerChoice.risk,
      );
      expect(result.userScoreDelta, 0);
      expect(result.aiScoreDelta, -20);
    });

    test('Çifte Riske Gir puanı 2 ile çarpar (kazanma)', () {
      final result = ScoringService.calculate(
        userCard: const PlayingCard(suit: Suit.spades, rank: 7),
        userChoice: PlayerChoice.doubleRisk,
        aiCard: const PlayingCard(suit: Suit.hearts, rank: 5),
        aiChoice: PlayerChoice.risk,
      );
      expect(result.userScoreDelta, 100);
      // Rakip tekli 'risk' secti (cifte degil), bu yuzden carpan 1'dir.
      expect(result.aiScoreDelta, -40);
    });

    test('Çifte Riske Gir puanı 2 ile çarpar (kaybetme)', () {
      final result = ScoringService.calculate(
        userCard: const PlayingCard(suit: Suit.spades, rank: 5),
        userChoice: PlayerChoice.doubleRisk,
        aiCard: const PlayingCard(suit: Suit.hearts, rank: 7),
        aiChoice: PlayerChoice.risk,
      );
      expect(result.userScoreDelta, -80);
      // Rakip tekli 'risk' secti (cifte degil), bu yuzden carpan 1'dir.
      expect(result.aiScoreDelta, 50);
    });
  });
}
