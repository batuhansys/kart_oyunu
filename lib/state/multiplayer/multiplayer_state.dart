import '../../domain/entities/mp_history_entry.dart';
import '../../domain/entities/player_choice.dart';
import '../../domain/entities/playing_card.dart';

/// Coklu oyunculu akisin hangi asamada oldugunu belirtir.
enum MpStage {
  /// Soket henuz baglanmadi / lobiye hic girilmedi.
  disconnected,

  /// Sunucuya baglaniliyor.
  connecting,

  /// Baglandi, ana lobi menusu gosteriliyor (Hizli Eslesme / Oda Kur / Katil).
  menu,

  /// Hizli eslesme kuyrugunda rakip bekleniyor.
  searchingQuickMatch,

  /// Oda kuruldu, kod paylasildi, rakibin katilmasi bekleniyor.
  roomWaitingForOpponent,

  /// Esleşme bulundu, el oynaniyor.
  playing,

  /// Oyun bitti (kazanan/kaybeden ekrani gosteriliyor).
  finished,
}

class MultiplayerState {
  final MpStage stage;
  final String? errorMessage;

  // Lobi
  final String? roomCode;

  // Esleşme / oyun
  final int? myIndex;
  final String? opponentName;
  final int roundId;
  final PlayingCard? yourCard;
  final PlayingCard? opponentCard; // sadece acilim (reveal) aninda dolu
  final PlayerChoice? yourChoice;
  final PlayerChoice? opponentChoice;
  final bool opponentHasChosen;
  final int yourScore;
  final int opponentScore;
  final int yourConsecutivePasses;
  final List<MpHistoryEntry> history;

  // Oyun sonu
  final bool? youWon; // null: berabere/ikisi de kaybetti
  final String? finishReason; // 'score' | 'opponent_left' | 'opponent_disconnected'

  const MultiplayerState({
    this.stage = MpStage.disconnected,
    this.errorMessage,
    this.roomCode,
    this.myIndex,
    this.opponentName,
    this.roundId = 0,
    this.yourCard,
    this.opponentCard,
    this.yourChoice,
    this.opponentChoice,
    this.opponentHasChosen = false,
    this.yourScore = 0,
    this.opponentScore = 0,
    this.yourConsecutivePasses = 0,
    this.history = const [],
    this.youWon,
    this.finishReason,
  });

  bool get canPass => yourConsecutivePasses < 2; // kMaxConsecutivePasses ile ayni kural

  MultiplayerState copyWith({
    MpStage? stage,
    String? errorMessage,
    bool clearError = false,
    String? roomCode,
    bool clearRoomCode = false,
    int? myIndex,
    String? opponentName,
    int? roundId,
    PlayingCard? yourCard,
    PlayingCard? opponentCard,
    bool clearOpponentCard = false,
    PlayerChoice? yourChoice,
    bool clearYourChoice = false,
    PlayerChoice? opponentChoice,
    bool clearOpponentChoice = false,
    bool? opponentHasChosen,
    int? yourScore,
    int? opponentScore,
    int? yourConsecutivePasses,
    List<MpHistoryEntry>? history,
    bool? youWon,
    bool clearYouWon = false,
    String? finishReason,
  }) {
    return MultiplayerState(
      stage: stage ?? this.stage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      roomCode: clearRoomCode ? null : (roomCode ?? this.roomCode),
      myIndex: myIndex ?? this.myIndex,
      opponentName: opponentName ?? this.opponentName,
      roundId: roundId ?? this.roundId,
      yourCard: yourCard ?? this.yourCard,
      opponentCard: clearOpponentCard ? null : (opponentCard ?? this.opponentCard),
      yourChoice: clearYourChoice ? null : (yourChoice ?? this.yourChoice),
      opponentChoice: clearOpponentChoice ? null : (opponentChoice ?? this.opponentChoice),
      opponentHasChosen: opponentHasChosen ?? this.opponentHasChosen,
      yourScore: yourScore ?? this.yourScore,
      opponentScore: opponentScore ?? this.opponentScore,
      yourConsecutivePasses: yourConsecutivePasses ?? this.yourConsecutivePasses,
      history: history ?? this.history,
      youWon: clearYouWon ? null : (youWon ?? this.youWon),
      finishReason: finishReason ?? this.finishReason,
    );
  }
}
