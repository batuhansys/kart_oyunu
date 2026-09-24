import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dokunulduğunda hafifçe küçülen, bırakılınca geri büyüyen ve hafif
/// dokunsal geri bildirim (haptic) veren, herhangi bir widget'ı
/// sarabilen etkileşim wrapper'ı. Menü kartları, tercih butonları gibi
/// tüm ana etkileşim noktalarında kullanılır; standart ElevatedButton'a
/// göre daha "tokta" ve premium bir his verir.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.94,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
