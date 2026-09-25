import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/result.dart';
import '../../domain/repositories/economy_repository.dart';

/// [EconomyRepository]'nin gerçek Cloud Firestore + REST implementasyonu.
/// Bakiye `users/{uid}.riskCoin` alanında tutulur; [watchBalance] bu alanı
/// gerçek zamanlı dinler, böylece bakiye sunucu tarafından (örn. çok
/// oyunculu maç ödülü, mağaza satın alma) değiştirildiğinde de anında
/// yansır. Yazma tarafı artık tamamen sunucuda: [purchasePackage]
/// `/api/shop/purchase` REST ucunu çağırır (bkz. server/server.js).
class FirebaseEconomyRepository implements EconomyRepository {
  FirebaseEconomyRepository({required ApiClient apiClient, FirebaseFirestore? firestore})
      : _apiClient = apiClient,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final ApiClient _apiClient;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Stream<int> watchBalance(String uid) {
    return _userDoc(uid).snapshots().map((doc) => (doc.data()?['riskCoin'] as num?)?.toInt() ?? 0);
  }

  @override
  Future<void> adjustBalance(String uid, int delta) async {
    // Kasıtlı olarak boş: riskCoin artık sadece sunucu tarafından
    // yazılabilir (bkz. dosya başı ve firestore.rules). Gerçek
    // değişiklikler watchBalance dinleyicisiyle kendiliğinden yansır.
  }

  @override
  Future<Result<int>> purchasePackage(String uid, int rcAmount) async {
    try {
      await _apiClient.post('/api/shop/purchase', body: {'amount': rcAmount});
      return Success(rcAmount);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Satın alma tamamlanamadı: $e');
    }
  }
}
