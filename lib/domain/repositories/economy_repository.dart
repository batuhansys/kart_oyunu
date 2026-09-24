import '../../core/utils/result.dart';

/// Ekonomi/satın alma işlemleri için soyut arayüz. Gerçek uygulamada
/// [purchasePackage], Google Play Billing / App Store makbuz
/// doğrulamasını burada (veya bir backend çağrısı üzerinden) yapar.
abstract class EconomyRepository {
  /// Bir mağaza paketini satın alır ve başarılıysa eklenen RC
  /// miktarını döner.
  Future<Result<int>> purchasePackage(int rcAmount);
}
