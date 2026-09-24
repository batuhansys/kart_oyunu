import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Oturum boyunca oynanan elleri özetleyen basit istatistikler.
/// NOT: Uygulamada henüz kalıcı depolama (SharedPreferences vb.) yok,
/// bu yüzden bu istatistikler de diğer tüm state gibi sadece uygulama
/// açıkken tutulur.
class GameStatsState {
  final int wins;
  final int losses;
  final int draws;
  final int currentStreak;
  final int bestStreak;

  const GameStatsState({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  int get gamesPlayed => wins + losses + draws;

  double get winRate => gamesPlayed == 0 ? 0 : wins / gamesPlayed;

  GameStatsState copyWith({
    int? wins,
    int? losses,
    int? draws,
    int? currentStreak,
    int? bestStreak,
  }) {
    return GameStatsState(
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
    );
  }
}

class GameStatsNotifier extends StateNotifier<GameStatsState> {
  GameStatsNotifier() : super(const GameStatsState());

  void recordWin() {
    final streak = state.currentStreak >= 0 ? state.currentStreak + 1 : 1;
    state = state.copyWith(
      wins: state.wins + 1,
      currentStreak: streak,
      bestStreak: streak > state.bestStreak ? streak : state.bestStreak,
    );
  }

  void recordLoss() {
    final streak = state.currentStreak <= 0 ? state.currentStreak - 1 : -1;
    state = state.copyWith(losses: state.losses + 1, currentStreak: streak);
  }

  void recordDraw() {
    state = state.copyWith(draws: state.draws + 1, currentStreak: 0);
  }
}

final gameStatsProvider = StateNotifierProvider<GameStatsNotifier, GameStatsState>((ref) {
  return GameStatsNotifier();
});
