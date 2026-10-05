import 'package:flutter/material.dart';

/// Okey tasi renkleri: 0 sari, 1 mavi, 2 siyah, 3 kirmizi.
const List<Color> kOkeyColors = [
  Color(0xFFE5A100),
  Color(0xFF1565C0),
  Color(0xFF212121),
  Color(0xFFD32F2F),
];

const List<String> kOkeyColorNames = ['Sarı', 'Mavi', 'Siyah', 'Kırmızı'];

/// Tek bir okey tasi. Yukseklik = genislik * 1.4. Sahte okey yesil yildizla,
/// gercek okey (joker) sag ustteki altin yildizla isaretlenir.
class OkeyTileView extends StatelessWidget {
  final int color;
  final int number;
  final bool fake;
  final bool joker;
  final double width;
  final bool dim;
  final bool highlight;
  final bool faceDown;

  const OkeyTileView({
    super.key,
    required this.color,
    required this.number,
    required this.width,
    this.fake = false,
    this.joker = false,
    this.dim = false,
    this.highlight = false,
    this.faceDown = false,
  });

  double get height => width * 1.4;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(width * 0.14);

    if (faceDown) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF8D6E3F),
          borderRadius: radius,
          border: Border.all(color: const Color(0xFF5D4524), width: 1.2),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1.5))],
        ),
      );
    }

    final face = fake ? const Color(0xFF2E7D32) : kOkeyColors[color.clamp(0, 3)];
    return Opacity(
      opacity: dim ? 0.45 : 1,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF3E0),
          borderRadius: radius,
          border: Border.all(
            color: highlight ? const Color(0xFFFFD54F) : const Color(0xFFBFB08A),
            width: highlight ? 2.4 : 1,
          ),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1.5))],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (fake)
              Icon(Icons.stars, color: face, size: width * 0.62)
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$number',
                    style: TextStyle(
                      color: face,
                      fontSize: width * 0.52,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: width * 0.06),
                  Container(
                    width: width * 0.2,
                    height: width * 0.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: face, width: width * 0.05),
                    ),
                  ),
                ],
              ),
              ),
            if (joker)
              Positioned(
                top: width * 0.04,
                right: width * 0.04,
                child: Icon(Icons.star, color: const Color(0xFFFFB300), size: width * 0.3),
              ),
          ],
        ),
      ),
    );
  }
}
