import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../state/sound_provider.dart';

enum GameOutcome { won, lost, bothLost }

class GameResultArgs {
  final GameOutcome outcome;
  final int rewardAmount;
  final String cityName;

  const GameResultArgs({
    required this.outcome,
    required this.rewardAmount,
    required this.cityName,
  });
}

class GameResultScreen extends ConsumerStatefulWidget {
  final GameResultArgs args;
  const GameResultScreen({super.key, required this.args});

  @override
  ConsumerState<GameResultScreen> createState() => _GameResultScreenState();
}

class _GameResultScreenState extends ConsumerState<GameResultScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    // Ses/konfeti gibi yan etkileri build() dışında, ilk frame sonrası
    // tetikliyoruz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sound = ref.read(soundServiceProvider);
      if (widget.args.outcome == GameOutcome.won) {
        _confettiController.play();
        sound.playWin();
      } else {
        sound.playLose();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final won = args.outcome == GameOutcome.won;

    late final String title;
    late final IconData icon;
    late final Color iconColor;
    switch (args.outcome) {
      case GameOutcome.won:
        title = 'Kazandın!';
        icon = Icons.emoji_events;
        iconColor = AppColors.gold;
        break;
      case GameOutcome.lost:
        title = 'Kaybettin';
        icon = Icons.sentiment_dissatisfied;
        iconColor = Colors.white54;
        break;
      case GameOutcome.bothLost:
        title = 'Berabere — İkiniz de kaybettiniz';
        icon = Icons.handshake;
        iconColor = Colors.white54;
        break;
    }

    return Scaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 96),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('${args.cityName} masası', style: const TextStyle(color: Colors.white70)),
                if (won) ...[
                  const SizedBox(height: 12),
                  Text(
                    '+${args.rewardAmount} RC',
                    style: const TextStyle(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text('+1 ${args.cityName} parçası', style: const TextStyle(color: Colors.white70)),
                ],
                const SizedBox(height: 32),
                PressableScale(
                  onTap: () => context.go('/home'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(14)),
                    child: const Text('Ana Menü', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [AppColors.gold, AppColors.goldLight, AppColors.riskBlue],
          ),
        ],
      ),
    );
  }
}
