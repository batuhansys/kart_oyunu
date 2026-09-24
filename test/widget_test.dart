import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// pubspec.yaml'daki gercek paket adi 'risk_get_and_gain' (klasor adi
// 'kart_oyunu' olsa da) - Dart import'lari pubspec.yaml'daki 'name:'
// alanini kullanir, klasor adini degil.
import 'package:risk_get_and_gain/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Yükleniyor ekranı başlatma testi', (WidgetTester tester) async {
    // Uygulamamızı test ortamında ayağa kaldırıyoruz
    await tester.pumpWidget(const ProviderScope(child: RiskGetAndGainApp()));

    // Ekranda 'RİSK GET AND GAIN' yazısının veya CircularProgressIndicator'ın olduğunu doğrulayalım
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // SplashScreen, 1600ms sonra otomatik olarak /login'e yönlendiren bir
    // Future.delayed zamanlayıcısı baslatir. Test bitmeden bu sureyi ileri
    // sararak zamanlayicinin calisip tamamlanmasini sagliyoruz; aksi halde
    // "asili zamanlayici" hatasi alinir.
    await tester.pump(const Duration(milliseconds: 1700));
  });
}