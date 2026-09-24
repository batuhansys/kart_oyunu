import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import 'user_id_generator.dart';

/// Uygulama genelindeki oturum/ekonomi durumunu tutar.
///
/// NOT: Bu sürümde kimlik doğrulama tamamen yereldir (gerçek bir backend
/// veya Firebase bağlanmamıştır). Gerçek kullanıma geçmeden önce:
///   - login/register metodları gerçek bir auth servisine bağlanmalı
///   - kullanıcı adı benzersizlik kontrolü backend'de yapılmalı
///   - riskCoin bakiyesi sunucu tarafında doğrulanmalı (client'a
///     güvenilmemeli, hile önleme için)
class AppSession extends ChangeNotifier {
  bool isLoggedIn = false;
  UserProfile? profile;

  /// Yeni hesap başlangıç bakiyesi kural gereği 1.000 RC'dir.
  int riskCoin = 1000;

  void login(String username) {
    profile = UserProfile(
      username: username,
      userId: UserIdGenerator.generate(),
    );
    isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    isLoggedIn = false;
    profile = null;
    notifyListeners();
  }

  bool canAfford(int amount) => riskCoin >= amount;

  void deduct(int amount) {
    riskCoin -= amount;
    notifyListeners();
  }

  void add(int amount) {
    riskCoin += amount;
    notifyListeners();
  }
}
