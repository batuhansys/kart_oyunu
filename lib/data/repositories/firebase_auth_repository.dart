import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import '../../core/utils/result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

/// [AuthRepository]'nin gerçek Firebase Auth + Cloud Firestore
/// implementasyonu.
///
/// Uygulamanın kullanıcı adı/şifre ile giriş UX'ini korumak için Firebase
/// Auth'un e-posta alanına, kullanıcı adından türetilen sahte bir e-posta
/// (`{kullaniciadi}@kartoyunu.app`) yazılır — bu sayede Firebase Auth'un
/// kendi e-posta benzersizliği, kullanıcı adı benzersizliğini de ücretsiz
/// sağlar (iki kişi aynı kullanıcı adıyla kayıt olmaya çalışırsa ikincisi
/// `email-already-in-use` hatası alır). Gerçek profil verisi (kullanıcı
/// adı, RC bakiyesi, seviye, arkadaşlar) `users/{uid}` dokümanında tutulur.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb_auth.FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? fb_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final fb_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static String _emailFor(String username) => '${username.trim().toLowerCase()}@kartoyunu.app';

  @override
  Future<Result<UserProfile>> login({
    required String username,
    required String password,
  }) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return const Failure('Kullanıcı adı boş olamaz.');
    if (password.isEmpty) return const Failure('Şifre boş olamaz.');

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: _emailFor(trimmed),
        password: password,
      );
      final uid = credential.user!.uid;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        return const Failure('Kullanıcı profili bulunamadı. Lütfen destek ile iletişime geçin.');
      }
      return Success(_profileFromDoc(uid, doc.data()!));
    } on fb_auth.FirebaseAuthException catch (e) {
      return Failure(_mapAuthError(e));
    } catch (e) {
      return Failure('Giriş başarısız: $e');
    }
  }

  @override
  Future<Result<UserProfile>> register({
    required String username,
    required RegisterMethod method,
    String? password,
  }) async {
    if (method == RegisterMethod.facebook) {
      return const Failure('Facebook ile kayıt yakında eklenecek. Şimdilik e-posta ile kayıt olun.');
    }

    final trimmed = username.trim();
    if (trimmed.isEmpty) return const Failure('Kullanıcı adı boş olamaz.');
    if (trimmed.length < 3) return const Failure('Kullanıcı adı en az 3 karakter olmalı.');
    if (password == null || password.length < 6) {
      return const Failure('Şifre en az 6 karakter olmalı.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _emailFor(trimmed),
        password: password,
      );
      final uid = credential.user!.uid;
      final usernameLower = trimmed.toLowerCase();

      final batch = _firestore.batch();
      batch.set(_firestore.collection('usernames').doc(usernameLower), {'uid': uid});
      batch.set(_firestore.collection('users').doc(uid), {
        'username': trimmed,
        'usernameLower': usernameLower,
        'level': 1,
        'xp': 0,
        'riskCoin': 1000,
        'isAdmin': false,
        'isRoyalPass': false,
        'pendingLevelRewards': <Map<String, dynamic>>[],
        'friendUids': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      return Success(UserProfile(username: trimmed, userId: uid));
    } on fb_auth.FirebaseAuthException catch (e) {
      return Failure(_mapAuthError(e));
    } catch (e) {
      return Failure('Kayıt başarısız: $e');
    }
  }

  @override
  Future<void> logout() => _auth.signOut();

  UserProfile _profileFromDoc(String uid, Map<String, dynamic> data) {
    return UserProfile(
      username: data['username'] as String? ?? 'Oyuncu',
      userId: uid,
      level: (data['level'] as num?)?.toInt() ?? 1,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
    );
  }

  String _mapAuthError(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Kullanıcı adı veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu kullanıcı adı zaten alınmış.';
      case 'weak-password':
        return 'Şifre çok zayıf, en az 6 karakter kullanın.';
      case 'network-request-failed':
        return 'Ağ bağlantısı hatası. İnternetinizi kontrol edin.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.';
      default:
        return 'Bir hata oluştu: ${e.message ?? e.code}';
    }
  }
}
