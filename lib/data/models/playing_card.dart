import 'dart:math';

enum Suit { spades, hearts, diamonds, clubs }

/// Bir iskambil kartını temsil eder.
/// rank: 2-10 arası düz değer, J=11, Q=12, K=13, A=14 (en yüksek).
class PlayingCard {
  final Suit suit;
  final int rank;

  const PlayingCard({required this.suit, required this.rank});

  static const List<int> allRanks = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];

  bool get isBluffCard => rank == 2 || rank == 14; // 2 ve A: blöf kartları

  String get rankLabel {
    switch (rank) {
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      case 14:
        return 'A';
      default:
        return rank.toString();
    }
  }

  String get suitSymbol {
    switch (suit) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  /// Not: Kaynak dokümana göre deste sabit/sayılamaz kabul edilir
  /// (bir kartın önceki elde çıkmış olması sonraki elde çıkma
  /// olasılığını etkilemez). Bu yüzden her el bağımsız rastgele
  /// üretim kullanılır, gerçek 52'lik desteden çekim simüle edilmez.
  factory PlayingCard.random(Random random) {
    final suit = Suit.values[random.nextInt(Suit.values.length)];
    final rank = allRanks[random.nextInt(allRanks.length)];
    return PlayingCard(suit: suit, rank: rank);
  }

  @override
  String toString() => '$rankLabel$suitSymbol';
}
