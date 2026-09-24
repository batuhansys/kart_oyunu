import 'playing_card.dart';
import 'player_choice.dart';

/// Coklu oyunculu mod icin "son eller" panelinde gosterilen tek bir el
/// kaydi. domain/entities/game_history_entry.dart ile ayni amaca hizmet
/// eder; sadece 'ai' yerine 'opponent' (gercek rakip) adlandirmasi
/// kullanilir.
class MpHistoryEntry {
  final PlayingCard yourCard;
  final PlayingCard opponentCard;
  final PlayerChoice yourChoice;
  final PlayerChoice opponentChoice;
  final int yourDelta;
  final int opponentDelta;

  const MpHistoryEntry({
    required this.yourCard,
    required this.opponentCard,
    required this.yourChoice,
    required this.opponentChoice,
    required this.yourDelta,
    required this.opponentDelta,
  });
}
