import '../../core/utils/result.dart';
import '../entities/user_profile.dart';

enum RegisterMethod { email, facebook }

/// Kimlik doğrulama işlemleri için soyut arayüz. Bu sayede UI ve state
/// katmanı, gerçek implementasyonun yerel mi (bu sürümde) yoksa
/// Firebase/REST API mi olduğunu bilmek zorunda kalmaz — ileride
/// [LocalAuthRepository] yerine `FirebaseAuthRepository` yazıp
/// bağlamak yeterlidir, başka hiçbir kod değişmez.
abstract class AuthRepository {
  Future<Result<UserProfile>> login({
    required String username,
    required String password,
  });

  Future<Result<UserProfile>> register({
    required String username,
    required RegisterMethod method,
    String? password,
  });

  Future<void> logout();
}
