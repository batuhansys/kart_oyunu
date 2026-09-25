import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../domain/entities/player_choice.dart';

/// Riske Gir / Çifte Riske Gir / Pas Geç butonları. Renkler işlevseldir
/// ve sabit tutulmalıdır (bkz. AppColors). PressableScale sayesinde her
/// tıklamada hafif bir "basılma" hissi ve dokunsal geri bildirim verir.
/// "Masadan Kalk" artık burada değil, oyun ekranının AppBar'ında bir
/// çıkış ikonu olarak yer alıyor.
class ChoiceButtons extends StatelessWidget {
  final bool enabled;
  final bool canPass;
  final void Function(PlayerChoice) onChoice;

  const ChoiceButtons({
    super.key,
    required this.enabled,
    required this.canPass,
    required this.onChoice,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
