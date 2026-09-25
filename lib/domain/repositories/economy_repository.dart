import '../../core/utils/result.dart';

/// Ekonomi/satın alma işlemleri için soyut arayüz. Gerçek uygulamada
/// [purchasePackage], Google Play Billing / App Store makbuz
/// doğrulamasını burada (veya bir backend çağrısı üzerinden) yapar.
abstract class EconomyRepository {
  /// Kullanıcının bakiyesini gerçek zamanlı izler.
  Stream<int> watchBalance(String uid);

  /// Bakiyeyi verilen miktar kadar değiştirir (negatif = düş, pozitif =
  /// ekle). Tek oyunculu şehir girişi/ödülü gibi client-taraflı
  /// senaryolar için kullanılır; çok oyunculu şehir maçlarının giriş
  /// ücreti/ödülü ise sunucu (Node/firebase-admin) üzerinden, bu
  /// repository'yi hiç kullanmadan, yetkili şekilde işlenir.
  Future<void> adjustBalance(String uid, int delta);

  /// Bir mağaza paketini satın alır ve başarılıysa eklenen RC
  /// miktarını döner.
  Future<Result<int>> purchasePackage(String uid, int rcAmount);
}
