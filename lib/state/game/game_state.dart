import '../../domain/entities/game_history_entry.dart';
import '../../domain/entities/player_choice.dart';
import '../../domain/entities/playing_card.dart';

enum GamePhase { dealing, waitingForChoices, revealing, scoring, gameOver }

/// Oyun masasının o anki tüm durumunu tutan değişmez (immutable) veri
/// sınıfı. GameNotifier bu sınıfın yeni kopyalarını üreterek state'i
/// günceller; UI sadece bu sınıfı izler.
class GameState {
  final GamePhase phase;
  final PlayingCard userCard;
  final PlayingCard aiCard;
  final PlayerChoice? userChoice;
  final PlayerChoice? aiChoice;
  final int userScore;
  final int aiScore;
  final bool isUserFirstThisRound;
  final int userConsecutivePasses;
  final int aiConsecutivePasses;
  final List<GameHistoryEntry> history;
  final String? winner; // 'user' | 'ai' | null
  final bool isGameOver;

  /// Her yeni el dağıtımında bir artar. UI, zamanlayıcıyı ne zaman
  /// yeniden başlatacağını kart nesnelerini karşılaştırmak yerine bu
  /// sayaç üzerinden güvenilir şekilde tespit eder.
  final int roundId;

  const GameState({
    required this.phase,
    required this.userCard,
    required this.aiCard,
    this.userChoice,
    this.aiChoice,
    this.userScore = 0,
    this.aiScore = 0,
    this.isUserFirstThisRound = true,
    this.userConsecutivePasses = 0,
    this.aiConsecutivePasses = 0,
    this.history = const [],
    this.winner,
    this.isGameOver = false,
    this.roundId = 0,
  });

  factory GameState.placeholder() {
    const placeholder = PlayingCard(suit: Suit.spades, rank: 2);
    return const GameState(phase: GamePhase.dealing, userCard: placeholder, aiCard: placeholder);
  }

  /// userChoice/aiChoice'ı null'a "sıfırlamaz" (yeni el için GameNotifier
  /// doğrudan yeni bir GameState inşa eder); bu metod sadece mevcut elin
  /// içindeki alanları güncellemek için kullanılır.
  GameState copyWith({
    GamePhase? phase,
    PlayerChoice? userChoice,
    PlayerChoice? aiChoice,
    int? userScore,
    int? aiScore,
    int? userConsecutivePasses,
    int? aiConsecutivePasses,
    List<GameHistoryEntry>? history,
    String? winner,
    bool? isGameOver,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      userCard: userCard,
      aiCard: aiCard,
      userChoice: userChoice ?? this.userChoice,
      aiChoice: aiChoice ?? this.aiChoice,
      userScore: userScore ?? this.userScore,
      aiScore: aiScore ?? this.aiScore,
      isUserFirstThisRound: isUserFirstThisRound,
      userConsecutivePasses: userConsecutivePasses ?? this.userConsecutivePasses,
      aiConsecutivePasses: aiConsecutivePasses ?? this.aiConsecutivePasses,
      history: history ?? this.history,
      winner: winner ?? this.winner,
      isGameOver: isGameOver ?? this.isGameOver,
      roundId: roundId,
    );
  }
}
