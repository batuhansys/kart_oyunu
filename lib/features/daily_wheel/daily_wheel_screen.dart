import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../state/sound_provider.dart';
import '../../state/wallet_provider.dart';

/// TODO: gerçek çark animasyonu ve 24 saatlik bekleme kontrolü (son
/// çevirme zamanının kalıcı olarak saklanması, örn. shared_preferences
/// ile) eklenmelidir.
class DailyWheelScreen extends ConsumerStatefulWidget {
  const DailyWheelScreen({super.key});

  @override
  ConsumerState<DailyWheelScreen> createState() => _DailyWheelScreenState();
}

class _DailyWheelScreenState extends ConsumerState<DailyWheelScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  bool _spun = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spun) return;
    setState(() => _spun = true);
    await _spinController.forward();
    ref.read(walletProvider.notifier).add(500);
    ref.read(soundServiceProvider).playCoin();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tebrikler! 500 RC kazandınız.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Günlük Çark')),
      body: GradientBackground(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              AnimatedBuilder(
                animation: _spinController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _spinController.value * 6 * 3.14159,
                    child: child,
                  );
                },
                child: Icon(
                  Icons.casino,
                  size: 96,
                  color: _spun ? Colors.white24 : AppColors.gold,
                ),
              ),
              const SizedBox(height: 24),
              PressableScale(
                onTap: _spun ? null : _spin,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: _spun ? Colors.white12 : AppColors.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _spun ? 'Bugün için çevirdiniz' : 'Çarkı Çevir',
                    style: TextStyle(
                      color: _spun ? Colors.white38 : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
