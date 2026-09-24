import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../domain/entities/player_choice.dart';

/// Riske Gir / Çifte Riske Gir / Pas Geç ve Masadan Kalk butonları.
/// Renkler işlevseldir ve sabit tutulmalıdır (bkz. AppColors).
/// PressableScale sayesinde her tıklamada hafif bir "basılma" hissi ve
/// dokunsal geri bildirim verir.
class ChoiceButtons extends StatelessWidget {
  final bool enabled;
  final bool canPass;
  final void Function(PlayerChoice) onChoice;
  final VoidCallback onLeaveTable;

  const ChoiceButtons({
    super.key,
    required this.enabled,
    required this.canPass,
    required this.onChoice,
    required this.onLeaveTable,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _choiceButton('Riske Gir', AppColors.riskBlue, enabled ? () => onChoice(PlayerChoice.risk) : null),
            _choiceButton(
              'Çifte Riske Gir',
              AppColors.doubleRiskNavy,
              enabled ? () => onChoice(PlayerChoice.doubleRisk) : null,
            ),
            _choiceButton(
              'Pas Geç',
              AppColors.passGray,
              (enabled && canPass) ? () => onChoice(PlayerChoice.pass) : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: PressableScale(
            onTap: onLeaveTable,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.foldRed,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: const Center(
                child: Text('Masadan Kalk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _choiceButton(String label, Color color, VoidCallback? onPressed) {
    final disabled = onPressed == null;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: PressableScale(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: disabled ? color.withOpacity(0.25) : color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: disabled
                  ? null
                  : [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, offset: const Offset(0, 3))],
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
