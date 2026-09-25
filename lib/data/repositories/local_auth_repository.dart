import '../../core/utils/result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/user_id_generator.dart';

/// [AuthRepository]'nin tamamen yerel (backend'siz) implementasyonu.
///
/// NOT: Gerçek kullanıma geçmeden önce bu sınıf, gerçek bir kimlik
/// doğrulama servisine (Firebase Auth, kendi REST API'niz vb.) bağlanan
/// bir implementasyonla DEĞİŞTİRİLMELİDİR. `AuthRepository` arayüzü
/// sayesinde bu değişiklik, çağıran kodun (AuthNotifier) hiçbir
/// satırını etkilemez — sadece Riverpod provider'ında bu sınıfın
/// yerine yenisi bağlanır.
class LocalAuthRepository implements AuthRepository {
  @override
  Future<Result<UserProfile>> login({
    required String username,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return const Failure('Kullanıcı adı boş olamaz.');
    }
    if (password.isEmpty) {
      return const Failure('Şifre boş olamaz.');
    }

    // TODO: gerçek backend'de kullanıcı adı/şifre burada doğrulanmalı.
    return Success(
      UserProfile(username: trimmed, userId: UserIdGenerator.generate()),
    );
  }

  @override
  Future<Result<UserProfile>> register({
    required String username,
    required RegisterMethod method,
    String? password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return const Failure('Kullanıcı adı boş olamaz.');
    }
    if (trimmed.length < 3) {
      return const Failure('Kullanıcı adı en az 3 karakter olmalı.');
    }

    // TODO: gerçek backend'de kullanıcı adı benzersizlik kontrolü
    // burada (transaction ile) yapılmalı; bu kontrol yapılmadan kayıt
    // tamamlanmamalıdır.
    return Success(
      UserProfile(username: trimmed, userId: UserIdGenerator.generate()),
    );
  }

  @override
  Future<void> logout() async {
    // Yerel implementasyonda temizlenecek bir oturum tokenı yok.
    // Gerçek implementasyonda burada backend'e logout isteği atılır
    // ve yerel token/cache temizlenir.
  }
}
