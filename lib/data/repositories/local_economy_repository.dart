import 'dart:async';
import 'dart:math';

import '../../core/utils/result.dart';
import '../../domain/repositories/economy_repository.dart';

/// [EconomyRepository]'nin yerel (gerçek ödeme almayan, kalıcı olmayan)
/// implementasyonu. Artık uygulamanın varsayılanı değildir (bkz.
/// main.dart — FirebaseEconomyRepository kullanılıyor); testlerde veya
/// backend'siz hızlı denemelerde referans/örnek olarak tutulmuştur.
class LocalEconomyRepository implements EconomyRepository {
  final Random _random = Random();
  final _balances = <String, int>{};
  final _controller = StreamController<MapEntry<String, int>>.broadcast();

  int _balanceFor(String uid) => _balances.putIfAbsent(uid, () => 1000);

  @override
  Stream<int> watchBalance(String uid) async* {
    yield _balanceFor(uid);
    yield* _controller.stream.where((e) => e.key == uid).map((e) => e.value);
  }

  @override
  Future<void> adjustBalance(String uid, int delta) async {
    final next = _balanceFor(uid) + delta;
    _balances[uid] = next;
    _controller.add(MapEntry(uid, next));
  }

  @override
  Future<Result<int>> purchasePackage(String uid, int rcAmount) async {
    await Future.delayed(const Duration(milliseconds: 600));

    // Gerçekçi bir his vermesi için nadiren (yaklaşık %3) simüle
    // edilmiş bir hata döner; gerçek implementasyonda bu, gerçek bir
    // ödeme/ağ hatası olur.
    if (_random.nextDouble() < 0.03) {
      return const Failure('Satın alma tamamlanamadı. Lütfen tekrar deneyin.');
    }

    await adjustBalance(uid, rcAmount);
    return Success(rcAmount);
  }
}
