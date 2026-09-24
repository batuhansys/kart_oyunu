import 'dart:math';

import '../../core/utils/result.dart';
import '../../domain/repositories/economy_repository.dart';

/// [EconomyRepository]'nin yerel (gerçek ödeme almayan) implementasyonu.
///
/// NOT: Gerçek kullanıma geçmeden önce bu sınıf, Google Play Billing
/// (in_app_purchase paketi) ile gerçek satın alma akışını ve makbuz
/// doğrulamasını yapan bir implementasyonla DEĞİŞTİRİLMELİDİR.
class LocalEconomyRepository implements EconomyRepository {
  final Random _random = Random();

  @override
  Future<Result<int>> purchasePackage(int rcAmount) async {
    await Future.delayed(const Duration(milliseconds: 600));

    // Gerçekçi bir his vermesi için nadiren (yaklaşık %3) simüle
    // edilmiş bir hata döner; gerçek implementasyonda bu, gerçek bir
    // ödeme/ağ hatası olur.
    if (_random.nextDouble() < 0.03) {
      return const Failure('Satın alma tamamlanamadı. Lütfen tekrar deneyin.');
    }

    return Success(rcAmount);
  }
}
