import 'dart:ui';

import 'package:flutter/material.dart';

/// Kartı çevreleyen bir zamanlayıcı çerçevesi çizer: süre başında
/// (progress=1) çerçeve en tepede kapanır (tam kare/tam halka), süre
/// azaldıkça tepeden itibaren simetrik olarak erir ve süre bittiğinde
/// (progress=0) en altta, tam ortada hizalı şekilde biter.
///
/// Flutter'ın `PathMetrics.extractPath` API'si kullanılır: kartın
/// köşeli dış hattı bir Path olarak alınır, üzerinde metrik hesaplanır
/// ve `progress` oranına göre bu path'in alt-orta noktadan başlayıp
/// iki yöne eşit uzayan bir bölümü çizilir. Bu, elle nokta-nokta
/// hesaplamaktan çok daha sağlam ve pürüzsüzdür.
///
/// progress: 1.0 (süre başı) -> 0.0 (süre sonu). Renk geçişi:
/// yeşil -> turuncu -> kırmızı. `overrideColor` verilirse (kullanıcı
/// bir tercih yaptıysa veya zaman aşımı olduysa) çerçeve o sabit
/// renkte tam kapalı durur: Riske Gir=mavi, Çifte Riske Gir=lacivert,
/// Pas Geç=gri, zaman aşımı=kırmızı.
class TimerRingPainter extends CustomPainter {
  final double progress;
  final Color? overrideColor;

  TimerRingPainter({required this.progress, this.overrideColor});

  // addRRect ile üretilen path'in tam olarak hangi noktadan başladığı
  // Skia'nın iç uygulamasına bağlıdır (üst-sol köşe olduğu
  // varsayılamaz) — bu yüzden üst-orta noktanın path üzerindeki
  // mesafesini varsaymak yerine örnekleyerek buluyoruz. Sadece `size`
  // sabit kaldığı sürece (kart boyutu değişmediği sürece) geçerlidir,
  // bu yüzden boyuta göre önbelleğe alınır.
  static final Map<Size, double> _topMidDistanceCache = {};

  double _findTopMidDistance(PathMetric metric, double totalLength, Size size) {
    return _topMidDistanceCache.putIfAbsent(size, () {
      final target = Offset(size.width / 2, 0);
      var bestDistance = 0.0;
      var bestError = double.infinity;
      const steps = 240;
      for (var i = 0; i < steps; i++) {
        final d = totalLength * i / steps;
        final tangent = metric.getTangentForOffset(d);
        if (tangent == null) continue;
        final error = (tangent.position - target).distanceSquared;
        if (error < bestError) {
          bestError = error;
          bestDistance = d;
        }
      }
      return bestDistance;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    final fullPath = Path()..addRRect(rrect);
    final metric = fullPath.computeMetrics().first;
    final totalLength = metric.length;

    // Üst-orta noktanın path üzerindeki gerçek mesafesini bulup, ondan
    // tam yarım tur (totalLength/2) ilerideki alt-orta noktayı
    // hesaplıyoruz.
    final topMidDistance = _findTopMidDistance(metric, totalLength, size);
    final bottomMidDistance = _normalize(topMidDistance + totalLength / 2, totalLength);

    final effectiveProgress = overrideColor != null ? 1.0 : progress.clamp(0.0, 1.0);
    final halfLength = (totalLength / 2) * effectiveProgress;

    final color = overrideColor ?? _colorForProgress(effectiveProgress);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    if (halfLength <= 0) return;

    // Alt-ortadan yukarı doğru (sağ yöne) yarım: süre azaldıkça üst
    // uçtan (tepeden) geriye doğru erir, alt-ortada sabit kalır.
    _drawForwardSegment(canvas, metric, totalLength, bottomMidDistance, halfLength, paint);
    // Alt-ortadan yukarı doğru (sol yöne) diğer yarım.
    final leftSegmentStart = _normalize(bottomMidDistance - halfLength, totalLength);
    _drawForwardSegment(canvas, metric, totalLength, leftSegmentStart, halfLength, paint);
  }

  double _normalize(double value, double total) {
    var result = value % total;
    if (result < 0) result += total;
    return result;
  }

  void _drawForwardSegment(
    Canvas canvas,
    PathMetric metric,
    double totalLength,
    double start,
    double length,
    Paint paint,
  ) {
    final end = start + length;
    if (end <= totalLength) {
      canvas.drawPath(metric.extractPath(start, end), paint);
    } else {
      canvas.drawPath(metric.extractPath(start, totalLength), paint);
      canvas.drawPath(metric.extractPath(0, end - totalLength), paint);
    }
  }

  Color _colorForProgress(double p) {
    if (p > 0.5) {
      return Color.lerp(Colors.orange, Colors.green, (p - 0.5) * 2)!;
    }
    return Color.lerp(Colors.red, Colors.orange, p * 2)!;
  }

  @override
  bool shouldRepaint(covariant TimerRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.overrideColor != overrideColor;
}
