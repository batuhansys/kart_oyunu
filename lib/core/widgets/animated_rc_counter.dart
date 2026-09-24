import 'package:flutter/material.dart';

/// RC bakiyesi her değiştiğinde eski değerden yeni değere doğru
/// sayarak animasyonlu şekilde geçiş yapan metin widget'ı. Basit bir
/// "+500 RC" değişikliğini bile fark edilir ve tatmin edici kılar.
class AnimatedRcCounter extends StatefulWidget {
  final int value;
  final TextStyle? style;

  const AnimatedRcCounter({super.key, required this.value, this.style});

  @override
  State<AnimatedRcCounter> createState() => _AnimatedRcCounterState();
}

class _AnimatedRcCounterState extends State<AnimatedRcCounter> {
  late int _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedRcCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previousValue = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: _previousValue, end: widget.value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text('$animatedValue RC', style: widget.style);
      },
    );
  }
}
