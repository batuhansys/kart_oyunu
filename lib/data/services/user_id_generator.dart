import 'dart:math';

/// 10 haneli, ilk hanesi 0 olmayan, art arda en fazla 3 hanesi aynı
/// olan kullanıcı ID'si üretir.
///
/// NOT: Bu sınıf sadece format kuralını (isValid) ve rastgele bir aday
/// üretimini (generate) sağlar. Gerçek benzersizlik kontrolü (başka
/// bir kullanıcıda bu ID'nin olup olmadığı) backend/veritabanı sorgusu
/// gerektirir; çağıran kod generate() ile ürettiği ID'yi backend'e
/// kontrol ettirip çakışma varsa tekrar generate() çağırmalıdır.
class UserIdGenerator {
  UserIdGenerator._();

  static final Random _random = Random.secure();

  static String generate() {
    String candidate;
    do {
      candidate = _generateCandidate();
    } while (!isValid(candidate));
    return candidate;
  }

  static String _generateCandidate() {
    final buffer = StringBuffer();
    buffer.write((_random.nextInt(9) + 1).toString()); // ilk hane 1-9
    for (int i = 0; i < 9; i++) {
      buffer.write(_random.nextInt(10).toString());
    }
    return buffer.toString();
  }

  /// Kuralları kontrol eder: 10 hane, ilk hane 0 değil, art arda en
  /// fazla 3 hane aynı.
  static bool isValid(String id) {
    if (id.length != 10) return false;
    if (!RegExp(r'^[0-9]{10}$').hasMatch(id)) return false;
    if (id.startsWith('0')) return false;

    int streak = 1;
    for (int i = 1; i < id.length; i++) {
      if (id[i] == id[i - 1]) {
        streak++;
        if (streak > 3) return false;
      } else {
        streak = 1;
      }
    }
    return true;
  }
}
