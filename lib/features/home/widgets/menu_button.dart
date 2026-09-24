import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable_scale.dart';

class MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool big;
  final VoidCallback onTap;

  const MenuButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = big ? 92.0 : 66.0;
    return PressableScale(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: big ? AppColors.gold : AppColors.surfaceDark,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
              boxShadow: [
                BoxShadow(
                  color: (big ? AppColors.gold : Colors.black).withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: big ? Colors.black : AppColors.gold, size: big ? 42 : 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
