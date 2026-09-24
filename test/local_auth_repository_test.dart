import 'package:flutter_test/flutter_test.dart';
import 'package:risk_get_and_gain/data/repositories/local_auth_repository.dart';
import 'package:risk_get_and_gain/domain/repositories/auth_repository.dart';

void main() {
  final repository = LocalAuthRepository();

  test('boş kullanıcı adıyla giriş başarısız olur', () async {
    final result = await repository.login(username: '', password: '1234');
    expect(result.isSuccess, isFalse);
  });

  test('boş şifreyle giriş başarısız olur', () async {
    final result = await repository.login(username: 'ahmet', password: '');
    expect(result.isSuccess, isFalse);
  });

  test('geçerli bilgilerle giriş başarılı olur ve 10 haneli bir ID üretir', () async {
    final result = await repository.login(username: 'ahmet', password: '1234');
    expect(result.isSuccess, isTrue);
    result.when(
      success: (profile) {
        expect(profile.username, 'ahmet');
        expect(profile.userId.length, 10);
      },
      failure: (message) => fail('Başarılı olması beklenirken başarısız oldu: $message'),
    );
  });

  test('3 karakterden kısa kullanıcı adıyla kayıt başarısız olur', () async {
    final result = await repository.register(username: 'ab', method: RegisterMethod.email);
    expect(result.isSuccess, isFalse);
  });

  test('geçerli kullanıcı adıyla kayıt başarılı olur', () async {
    final result = await repository.register(username: 'yeniOyuncu', method: RegisterMethod.facebook);
    expect(result.isSuccess, isTrue);
  });
}
