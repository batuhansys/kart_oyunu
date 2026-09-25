import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/game_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../domain/entities/player_choice.dart';
import '../../domain/entities/playing_card.dart';
import '../../state/multiplayer/multiplayer_notifier.dart';
import '../../state/multiplayer/multiplayer_state.dart';
import '../../state/sound_provider.dart';
import '../game/widgets/card_slot.dart';
import '../game/widgets/choice_buttons.dart';
import 'widgets/mp_history_panel.dart';

/// Coklu oyunculu oyun masasi. lib/features/game/game_table_screen.dart
/// ile ayni gorsel dili paylasir (ayni CardSlot/ChoiceButtons
/// widget'lari) ama state'i yerel bir AI yerine gercek sunucudan
/// (bkz. MultiplayerNotifier) alir. Zamanlayici burada sadece gorseldir
/// — asil zaman asimi kararini her zaman sunucu verir, bu yuzden
/// istemci "hile" yaparak suresiz bekleyemez.
class MultiplayerGameScreen extends ConsumerStatefulWidget {
  const MultiplayerGameScreen({super.key});

  @override
  ConsumerState<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends ConsumerState<MultiplayerGameScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timerController;
  bool _wasWaitingForYou = false;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: kDecisionSeconds),
    );
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
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
    final isActive = ref.read(multiplayerProvider).stage == MpStage.playing;
    if (!isActive) {
      _leaveToLobby();
      return;
    }
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
              _leaveToLobby();
            },
            child: const Text('Kalk', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _leaveToLobby() {
    ref.read(multiplayerProvider.notifier).leaveTable();
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(multiplayerProvider);

    ref.listen<MultiplayerState>(multiplayerProvider, (previous, next) {
      if (next.stage == MpStage.disconnected && previous?.stage != MpStage.disconnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Bağlantı koptu.'), backgroundColor: AppColors.foldRed),
        );
        if (context.canPop()) context.pop();
      }
    });

    // Sira tabanli oyunda "senin siran" iki farkli anda baslayabilir:
    // yeni el basinda (oncelik sendeyse) veya el ortasinda rakibin
    // secimi acildiginda (isYourTurn false'tan true'ya donunce). Bu
    // yuzden zamanlayiciyi roundId yerine bu geciste (false->true)
    // tetikliyoruz.
    final waitingForYou = state.stage == MpStage.playing &&
        state.yourCard != null &&
        state.yourChoice == null &&
        state.isYourTurn;
    if (waitingForYou && !_wasWaitingForYou) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _timerController
          ..stop()
          ..reset()
          ..forward();
      });
    } else if (!waitingForYou) {
      _timerController.stop();
    }
    _wasWaitingForYou = waitingForYou;

    String? turnStatusText;
    if (state.stage == MpStage.playing) {
      if (state.yourChoice != null) {
        turnStatusText = 'Rakip bekleniyor...';
      } else if (!state.isYourTurn) {
        turnStatusText = 'Önce rakip seçecek, bekleyin...';
      } else {
        turnStatusText = 'Sıra sende, tercihini yap!';
      }
    }

    final yourFrameColor = state.yourChoice == null ? null : _colorForChoice(state.yourChoice!);
    final opponentFrameColor = state.opponentChoice == null ? null : _colorForChoice(state.opponentChoice!);
    final opponentCardRevealed = state.opponentCard != null;
    const placeholderCard = PlayingCard(suit: Suit.spades, rank: 2);

    return Scaffold(
      appBar: AppBar(title: Text(state.opponentName != null ? 'vs ${state.opponentName}' : 'Çevrimiçi')),
      body: Stack(
        children: [
          GradientBackground(
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
                                  'Sen: ${state.yourScore}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                AnimatedBuilder(
                                  animation: _timerController,
                                  builder: (context, _) {
                                    return CardSlot(
                                      card: state.yourCard ?? placeholderCard,
                                      showFace: true,
                                      timerProgress: waitingForYou ? (1 - _timerController.value) : null,
                                      frameColor: yourFrameColor,
                                    );
                                  },
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${state.opponentName ?? 'Rakip'}: ${state.opponentScore}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                CardSlot(
                                  card: state.opponentCard ?? placeholderCard,
                                  showFace: opponentCardRevealed,
                                  frameColor: opponentFrameColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (turnStatusText != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              turnStatusText,
                              style: TextStyle(
                                color: state.isYourTurn && state.yourChoice == null
                                    ? AppColors.gold
                                    : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ChoiceButtons(
                            enabled: waitingForYou,
                            canPass: state.canPass,
                            onChoice: (choice) {
                              _timerController.stop();
                              ref.read(soundServiceProvider).playCardFlip();
                              ref.read(multiplayerProvider.notifier).submitChoice(choice);
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
                          Expanded(child: MpHistoryPanel(entries: state.history)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.stage == MpStage.finished) _buildResultOverlay(state),
        ],
      ),
    );
  }

  Widget _buildResultOverlay(MultiplayerState state) {
    final String title;
    final Color color;
    if (state.youWon == true) {
      title = 'Kazandın!';
      color = Colors.greenAccent.shade400;
    } else if (state.youWon == false) {
      title = 'Kaybettin';
      color = AppColors.foldRed;
    } else {
      title = 'Berabere';
      color = Colors.white70;
    }

    String? subtitle;
    if (state.finishReason == 'opponent_disconnected') {
      subtitle = 'Rakibin bağlantısı koptu.';
    } else if (state.finishReason == 'opponent_left') {
      subtitle = 'Rakibin masadan kalktı.';
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'Sen: ${state.yourScore}   •   ${state.opponentName ?? 'Rakip'}: ${state.opponentScore}',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.foldRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  ref.read(multiplayerProvider.notifier).backToMenuAfterFinish();
                  if (context.canPop()) context.pop();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text('Lobiye Dön'),
                ),
              ),
              const SizedBox(height: 12),
              if (state.finishReason != 'opponent_left' &&
                  state.finishReason != 'opponent_disconnected')
                _rematchButton(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rematchButton(MultiplayerState state) {
    late final String label;
    late final Color color;
    late final VoidCallback? onPressed;

    switch (state.rematchStatus) {
      case RematchStatus.none:
        label = 'Tekrar Meydan Oku';
        color = AppColors.gold;
        onPressed = () => ref.read(multiplayerProvider.notifier).requestRematch();
        break;
      case RematchStatus.requestedByMe:
        label = 'Rakip Bekleniyor...';
        color = Colors.green;
        onPressed = null;
        break;
      case RematchStatus.requestedByOpponent:
        label = 'Rakip Meydan Okudu! Kabul Et';
        color = Colors.green;
        onPressed = () => ref.read(multiplayerProvider.notifier).acceptRematch();
        break;
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.black,
        disabledBackgroundColor: color,
        disabledForegroundColor: Colors.black87,
      ),
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
