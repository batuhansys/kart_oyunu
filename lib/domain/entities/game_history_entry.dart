import 'playing_card.dart';
import 'player_choice.dart';

/// Sağ paneldeki "son 10 el" listesinde gösterilen tek bir el kaydı.
class GameHistoryEntry {
  final PlayingCard userCard;
  final PlayingCard aiCard;
  final PlayerChoice userChoice;
  final PlayerChoice aiChoice;
  final int userDelta;
  final int aiDelta;

  const GameHistoryEntry({
    required this.userCard,
    required this.aiCard,
    required this.userChoice,
    required this.aiChoice,
    required this.userDelta,
    required this.aiDelta,
  });
}
