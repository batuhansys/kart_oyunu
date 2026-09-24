import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/game_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../domain/entities/game_city.dart';
import '../../domain/entities/player_choice.dart';
import '../../state/game/game_providers.dart';
import '../../state/game/game_state.dart';
import '../../state/sound_provider.dart';
import '../../state/stats_provider.dart';
import '../../state/wallet_provider.dart';
import '../../state/workshop_provider.dart';
import '../game_result/game_result_screen.dart';
import 'widgets/card_slot.dart';
import 'widgets/choice_buttons.dart';
import 'widgets/history_panel.dart';

class GameTableScreen extends ConsumerStatefulWidget {
  final GameCity city;
  const GameTableScreen({super.key, required this.city});

  @override
  ConsumerState<GameTableScreen> createState() => _GameTableScreenState();
}

class _GameTableScreenState extends ConsumerState<GameTableScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timerController;
  int? _timerRoundId;
  bool _resultPushed = false;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: kDecisionSeconds),
    )..addStatusListener(_onTimerStatusChanged);
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  // Karar süresi tamamen dolduğunda (animasyon "completed" durumuna
  // ulaştığında) zaman aşımını GameNotifier'a bildirir; notifier zaten
  // hâlâ bekleniyor mu diye kontrol eder, bu yüzden burada ekstra
  // koşula gerek yoktur.
  void _onTimerStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      ref.read(gameNotifierProvider(widget.city.id).notifier).handleTimeout();
    }
  }

  Color _colorForChoice(PlayerChoice choice) {
    switch (choice) {
      case PlayerChoice.risk:
        return AppColors.riskBlue;
      case PlayerChoice.doubleRisk:
        return AppColors.doubleRiskNavy;
      case PlayerChoice.pass:
        return AppColors.passGray;
      case PlayerChoice.timeout:
        return AppColors.foldRed;
    }
  }

  void _confirmLeaveTable() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Masadan Kalk', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Masadan kalkarsanız rakip oyunu otomatik kazanır. Emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Oyuna Geri Dön')),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/home');
            },
            child: const Text('Kalk', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameStateProvider = gameNotifierProvider(widget.city.id);
    final state = ref.watch(gameStateProvider);
    final notifier = ref.read(gameStateProvider.notifier);

    // Oyun bitişini tek seferlik bir yan etki olarak dinliyoruz:
    // sonuç ekranına geçiş ve ödülün cüzdana eklenmesi burada olur.
    ref.listen<GameState>(gameStateProvider, (previous, next) {
      if (next.isGameOver && !_resultPushed) {
        _resultPushed = true;
        final outcome = next.winner == 'user'
            ? GameOutcome.won
            : (next.winner == 'ai' ? GameOutcome.lost : GameOutcome.bothLost);
        final reward = notifier.rewardIfWon;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          switch (outcome) {
            case GameOutcome.won:
              ref.read(walletProvider.notifier).add(reward);
              ref.read(gameStatsProvider.notifier).recordWin();
              ref.read(workshopProvider.notifier).addFragment(widget.city.id);
              break;
            case GameOutcome.lost:
              ref.read(gameStatsProvider.notifier).recordLoss();
              break;
            case GameOutcome.bothLost:
              ref.read(gameStatsProvider.notifier).recordDraw();
              break;
          }
          context.pushReplacement(
            '/game-result',
            extra: GameResultArgs(
              outcome: outcome,
              rewardAmount: outcome == GameOutcome.won ? reward : 0,
              cityName: widget.city.name,
            ),
          );
        });
      }
    });

    // Zamanlayıcıyı, kart nesnelerini karşılaştırmak yerine güvenilir
    // bir sayaç olan roundId üzerinden, her yeni el başladığında
    // (ve sıra kullanıcıdaysa) yeniden başlatıyoruz.
    final waitingForUser = state.phase == GamePhase.waitingForChoices && state.userChoice == null;
    if (waitingForUser && _timerRoundId != state.roundId) {
      _timerRoundId = state.roundId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _timerController
          ..stop()
          ..reset()
          ..forward();
      });
    } else if (!waitingForUser) {
      _timerController.stop();
    }

    final userFrameColor = state.userChoice == null ? null : _colorForChoice(state.userChoice!);
    final aiFrameColor = state.aiChoice == null ? null : _colorForChoice(state.aiChoice!);
    final aiCardRevealed = state.phase == GamePhase.revealing || state.phase == GamePhase.scoring;

    return Scaffold(
      appBar: AppBar(title: Text(widget.city.name)),
      body: GradientBackground(
        gradient: const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: [AppColors.feltGreen, AppColors.feltGreenDark],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Sen: ${state.userScore}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            AnimatedBuilder(
                              animation: _timerController,
                              builder: (context, _) {
                                return CardSlot(
                                  card: state.userCard,
                                  showFace: true,
                                  timerProgress: waitingForUser ? (1 - _timerController.value) : null,
                                  frameColor: userFrameColor,
                                );
                              },
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              'Rakip: ${state.aiScore}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            CardSlot(
                              card: state.aiCard,
                              showFace: aiCardRevealed,
                              frameColor: aiFrameColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ChoiceButtons(
                        enabled: state.phase == GamePhase.waitingForChoices && state.userChoice == null,
                        canPass: notifier.canUserPass,
                        onChoice: (choice) {
                          _timerController.stop();
                          ref.read(soundServiceProvider).playCardFlip();
                          notifier.submitUserChoice(choice);
                        },
                        onLeaveTable: _confirmLeaveTable,
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, color: Colors.white24),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Son Eller', style: TextStyle(color: Colors.white70)),
                      ),
                      Expanded(child: HistoryPanel(entries: state.history)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
