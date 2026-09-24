import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';

/// TODO: ses/müzik seviyeleri shared_preferences ile kalıcı hale
/// getirilmeli ve SoundService'e (bkz. data/services/sound_service.dart)
/// bağlanmalıdır.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _music = 0.7;
  double _sound = 0.7;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: GradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(alignment: Alignment.centerLeft, child: Text('Müzik', style: TextStyle(color: Colors.white))),
              Slider(
                value: _music,
                onChanged: (v) => setState(() => _music = v),
                activeColor: AppColors.gold,
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Ses Efektleri', style: TextStyle(color: Colors.white)),
              ),
              Slider(
                value: _sound,
                onChanged: (v) => setState(() => _sound = v),
                activeColor: AppColors.gold,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
