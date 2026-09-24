import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/game_constants.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/game_city.dart';
import '../../domain/entities/game_history_entry.dart';
import '../../domain/entities/player_choice.dart';
import '../../domain/entities/playing_card.dart';
import 'ai_decision_service.dart';
import 'game_state.dart';
import 'scoring_service.dart';

/// Oyun masasının tüm iş mantığını (kart dağıtma, sıra takibi, AI
/// kararı, puanlama, kazanma/kaybetme kontrolü) yöneten state machine.
///
/// UI'dan tamamen bağımsızdır (Flutter widget'ları burada yer almaz),
/// bu yüzden birim testleri Flutter test binding'i gerektirmeden
/// yazılabilir (bkz. test/game_notifier_test.dart).
class GameNotifier extends StateNotifier<GameState> {
  final GameCity city;
  final Random _random;

  bool _disposed = false;
  bool _tieBreakRound = false;

  GameNotifier({required this.city, Random? random})
      : _random = random ?? Random(),
        super(GameState.placeholder()) {
    _dealNewRound(isFirstRound: true);
  }

  bool get canUserPass => state.userConsecutivePasses < kMaxConsecutivePasses;
  int get rewardIfWon => city.rewardAmount;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _dealNewRound({bool isFirstRound = false}) {
    if (_disposed) return;

    final newUserCard = PlayingCard.random(_random);
    final newAiCard = PlayingCard.random(_random);
    final isUserFirst = isFirstRound ? true : !state.isUserFirstThisRound;

    // Sıra kimdeyse o önce karar verir; diğeri bu tercihi "görerek"
    // karar verir. AI ilk sıradaysa kararını hemen burada veriyoruz ki
    // UI, AI'nın çerçeve rengini el başında gösterebilsin.
    PlayerChoice? aiPreChoice;
    if (!isUserFirst) {
      aiPreChoice = AiDecisionService.decide(
        aiCard: newAiCard,
        consecutivePasses: state.aiConsecutivePasses,
      );
    }

    state = GameState(
      phase: GamePhase.waitingForChoices,
      userCard: newUserCard,
      aiCard: newAiCard,
      userChoice: null,
      aiChoice: aiPreChoice,
      userScore: state.userScore,
      aiScore: state.aiScore,
      isUserFirstThisRound: isUserFirst,
      userConsecutivePasses: state.userConsecutivePasses,
      aiConsecutivePasses: state.aiConsecutivePasses,
      history: state.history,
      winner: null,
      isGameOver: false,
      roundId: state.roundId + 1,
    );
  }

  /// Kullanıcı bir tercih yaptığında (UI'daki butonlardan) çağrılır.
  void submitUserChoice(PlayerChoice choice) {
    if (_disposed) return;
    if (state.phase != GamePhase.waitingForChoices || state.userChoice != null) return;
    if (choice == PlayerChoice.pass && !canUserPass) return;

    var aiChoice = state.aiChoice;
    if (state.isUserFirstThisRound) {
      // Sıradaki AI, kullanıcının tercihini "görerek" karar verir.
      aiChoice = AiDecisionService.decide(
        aiCard: state.aiCard,
        consecutivePasses: state.aiConsecutivePasses,
      );
    }

    state = state.copyWith(userChoice: choice, aiChoice: aiChoice, phase: GamePhase.revealing);
    _resolveRound();
  }

  /// 7 saniyelik karar süresi dolduğunda UI tarafından çağrılır.
  /// Kural: süre dolarsa tercih yapılmamış (zaman aşımı) kabul edilir;
  /// çerçeve kırmızıya döner. Puanlama pas'tan farklıdır (bkz.
  /// ScoringService.timeout): kazanan kart olsa dahi puan getirmez,
  /// kaybeden kartsa çifte riskin ceza puanını alır.
  void handleTimeout() {
    if (_disposed) return;
    if (state.phase != GamePhase.waitingForChoices || state.userChoice != null) return;

    var aiChoice = state.aiChoice;
    if (state.isUserFirstThisRound) {
      // Sıradaki AI, kullanıcının (zaman aşımına uğrayan) tercihini
      // "görerek" karar verir.
      aiChoice = AiDecisionService.decide(
        aiCard: state.aiCard,
        consecutivePasses: state.aiConsecutivePasses,
      );
    }

    state = state.copyWith(userChoice: PlayerChoice.timeout, aiChoice: aiChoice, phase: GamePhase.revealing);
    _resolveRound();
  }

  void _resolveRound() {
    final result = ScoringService.calculate(
      userCard: state.userCard,
      userChoice: state.userChoice!,
      aiCard: state.aiCard,
      aiChoice: state.aiChoice!,
    );

    final newUserScore = state.userScore + result.userScoreDelta;
    final newAiScore = state.aiScore + result.aiScoreDelta;

    final newUserPasses =
        state.userChoice == PlayerChoice.pass ? state.userConsecutivePasses + 1 : 0;
    final newAiPasses =
        state.aiChoice == PlayerChoice.pass ? state.aiConsecutivePasses + 1 : 0;

    final newHistory = <GameHistoryEntry>[
      GameHistoryEntry(
        userCard: state.userCard,
        aiCard: state.aiCard,
        userChoice: state.userChoice!,
        aiChoice: state.aiChoice!,
        userDelta: result.userScoreDelta,
        aiDelta: result.aiScoreDelta,
      ),
      ...state.history,
    ];
    if (newHistory.length > 10) newHistory.removeLast();

    state = state.copyWith(
      phase: GamePhase.scoring,
      userScore: newUserScore,
      aiScore: newAiScore,
      userConsecutivePasses: newUserPasses,
      aiConsecutivePasses: newAiPasses,
      history: newHistory,
    );

    _checkGameOver();
  }

  void _checkGameOver() {
    final userBusted = state.userScore <= kLoseScoreThreshold;
    final aiBusted = state.aiScore <= kLoseScoreThreshold;
    final userReachedTarget = state.userScore >= kWinScoreThreshold;
    final aiReachedTarget = state.aiScore >= kWinScoreThreshold;

    String? winner;
    bool gameOver = false;

    if (_tieBreakRound) {
      // Daha önce iki oyuncu da aynı elde -250 altına eşit puanla
      // düşmüştü ve bir el daha oynandı: kim daha yüksek puandaysa
      // kazanır. Yine eşitse ikisi de kaybetmiş sayılır (winner=null,
      // gameOver=true).
      _tieBreakRound = false;
      if (state.userScore != state.aiScore) {
        winner = state.userScore > state.aiScore ? 'user' : 'ai';
      }
      gameOver = true;
    } else if (userBusted && aiBusted) {
      if (state.userScore == state.aiScore) {
        _tieBreakRound = true;
      } else {
        // Daha düşük (daha negatif) olan kaybeder.
        winner = state.userScore > state.aiScore ? 'user' : 'ai';
        gameOver = true;
      }
    } else if (userBusted) {
      winner = 'ai';
      gameOver = true;
    } else if (aiBusted) {
      winner = 'user';
      gameOver = true;
    } else if (userReachedTarget && aiReachedTarget) {
      if (state.userScore != state.aiScore) {
        winner = state.userScore > state.aiScore ? 'user' : 'ai';
        gameOver = true;
      }
      // Not: aynı elde ikisi de 250'ye ulaşır ve puanları eşit kalırsa
      // bu uç durum kaynak dokümanda tanımlanmamıştır; burada oyun bir
      // el daha devam eder (ürün sahibiyle netleştirilmesi önerilir).
    } else if (userReachedTarget) {
      winner = 'user';
      gameOver = true;
    } else if (aiReachedTarget) {
      winner = 'ai';
      gameOver = true;
    }

    if (gameOver) {
      state = state.copyWith(phase: GamePhase.gameOver, winner: winner, isGameOver: true);
      AppLogger.info(
        'Oyun bitti (${city.name}). Kazanan: ${winner ?? 'berabere/ikisi de kaybetti'} '
        '(Sen: ${state.userScore}, Rakip: ${state.aiScore})',
      );
    } else {
      Future.delayed(const Duration(seconds: kResultDisplaySeconds), () {
        _dealNewRound();
      });
    }
  }
}
