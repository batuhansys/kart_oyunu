import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../state/daily_wheel_provider.dart';
import '../../state/sound_provider.dart';
import 'widgets/wheel_painter.dart';

const List<String> _kTierLabels = ['%1', '%2', '%4', '%10', '%20', '%50'];
const int _kSliceCount = 6;
const int _kExtraSpins = 5;

class DailyWheelScreen extends ConsumerStatefulWidget {
  const DailyWheelScreen({super.key});

  @override
  ConsumerState<DailyWheelScreen> createState() => _DailyWheelScreenState();
}

class _DailyWheelScreenState extends ConsumerState<DailyWheelScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double> _rotation = const AlwaysStoppedAnimation(0);
  double _currentAngle = 0;
  bool _isBusy = false;
  bool _showingAdOverlay = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _normalize(double angle) {
    const twoPi = 2 * math.pi;
    var a = angle % twoPi;
    if (a < 0) a += twoPi;
    return a;
  }

  /// Dilim [tierIndex]'in ortasını sabit (üstteki) ibreye getirmek için
  /// gereken toplam dönüş açısı; bkz. WheelPainter doc yorumu.
  double _targetRotationFor(int tierIndex) {
    final sliceAngle = 2 * math.pi / _kSliceCount;
    final targetMod = _normalize(-(tierIndex + 0.5) * sliceAngle);
    final currentMod = _normalize(_currentAngle);
    final deltaForward = _normalize(targetMod - currentMod);
    return _currentAngle + _kExtraSpins * 2 * math.pi + deltaForward;
  }

  Future<void> _doSpin(String type) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    if (type == 'ad') {
      setState(() => _showingAdOverlay = true);
      final waitSeconds = 3 + math.Random().nextInt(3); // 3-5 sn sahte reklam
      await Future.delayed(Duration(seconds: waitSeconds));
      if (!mounted) return;
      setState(() => _showingAdOverlay = false);
    }

    final result = await ref.read(dailyWheelProvider.notifier).spin(type);
    if (!mounted) return;

    if (result == null) {
      final error = ref.read(dailyWheelProvider).errorMessage;
      setState(() => _isBusy = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    final newAngle = _targetRotationFor(result.tierIndex);
    _controller.reset();
    _rotation = Tween<double>(begin: _currentAngle, end: newAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    await _controller.forward();
    _currentAngle = newAngle;
    if (!mounted) return;

    ref.read(soundServiceProvider).playCoin();
    setState(() => _isBusy = false);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Tebrikler!', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        content: Text('+${result.rewardRc} RC kazandınız!', style: const TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Harika!')),
        ],
      ),
    );
  }

  Widget _buildActionButton(DailyWheelState wheel) {
    if (wheel.freeAvailable) {
      return _spinButton(
        label: 'Ücretsiz Çevir',
        color: AppColors.gold,
        textColor: Colors.black,
        onTap: () => _doSpin('free'),
      );
    }
    if (wheel.adAvailable) {
      return _spinButton(
        label: 'Reklamı İzle ve Çevir',
        color: AppColors.riskBlue,
        textColor: Colors.white,
        icon: Icons.play_circle_fill,
        onTap: () => _doSpin('ad'),
      );
    }
    return const Text(
      'Bugünkü çevirmeleri kullandın, yarın tekrar gel!',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white54),
    );
  }

  Widget _spinButton({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return PressableScale(
      onTap: _isBusy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: _isBusy ? color.withOpacity(0.35) : color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, color: textColor, size: 20), const SizedBox(width: 8)],
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wheel = ref.watch(dailyWheelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Günlük Çark')),
      body: GradientBackground(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _rotation,
                            builder: (context, child) {
                              return Transform.rotate(angle: _rotation.value, child: child);
                            },
                            child: CustomPaint(
                              size: const Size(260, 260),
                              painter: const WheelPainter(_kTierLabels),
                            ),
                          ),
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.gold, width: 3),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'ÇEVİR',
                              style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const Positioned(
                            top: -6,
                            child: Icon(Icons.arrow_drop_down, size: 48, color: AppColors.gold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildActionButton(wheel),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (_showingAdOverlay)
              Container(
                color: Colors.black87,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: AppColors.gold),
                    SizedBox(height: 16),
                    Text('Reklam izleniyor...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
