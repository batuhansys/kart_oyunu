import 'package:flutter_test/flutter_test.dart';
import 'package:risk_get_and_gain/data/services/user_id_generator.dart';

void main() {
  group('UserIdGenerator', () {
    test('geçerli ID kabul edilir: 8782567222', () {
      expect(UserIdGenerator.isValid('8782567222'), isTrue);
    });

    test('geçersiz ID reddedilir: 6289888882 (art arda 5 kez 8)', () {
      expect(UserIdGenerator.isValid('6289888882'), isFalse);
    });

    test('0 ile başlayan ID reddedilir', () {
      expect(UserIdGenerator.isValid('0123456789'), isFalse);
    });

    test('10 haneden farklı uzunluk reddedilir', () {
      expect(UserIdGenerator.isValid('123456789'), isFalse);
      expect(UserIdGenerator.isValid('12345678901'), isFalse);
    });

    test('art arda tam 3 hane aynı olabilir (sınır durum)', () {
      expect(UserIdGenerator.isValid('1112345678'), isTrue);
    });

    test('generate() her zaman geçerli bir ID üretir', () {
      for (int i = 0; i < 200; i++) {
        final id = UserIdGenerator.generate();
        expect(UserIdGenerator.isValid(id), isTrue, reason: 'Geçersiz ID: $id');
      }
    });
  });
}
