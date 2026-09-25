import '../../core/utils/result.dart';

/// Ekonomi/satın alma işlemleri için soyut arayüz. Gerçek uygulamada
/// [purchasePackage], Google Play Billing / App Store makbuz
/// doğrulamasını burada (veya bir backend çağrısı üzerinden) yapar.
abstract class EconomyRepository {
  /// Kullanıcının bakiyesini gerçek zamanlı izler.
  Stream<int> watchBalance(String uid);

  /// ARTIK GERÇEK BİR YAZMA YAPMAZ: riskCoin sadece sunucu (firebase-admin)
  /// tarafından değiştirilebilir (bkz. firestore.rules users/{uid} update
  /// kuralı). Geriye dönük uyumluluk için arayüzde duruyor; gerçek bakiye
  /// değişiklikleri her zaman sunucudaki ilgili uçtan (maç ödülü, mağaza,
  /// çark, atölye) gelir ve [watchBalance] dinleyicisiyle otomatik yansır.
  Future<void> adjustBalance(String uid, int delta);

  /// Bir mağaza paketini satın alır ve başarılıysa eklenen RC
  /// miktarını döner.
  Future<Result<int>> purchasePackage(String uid, int rcAmount);
}
