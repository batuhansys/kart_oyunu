import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/result.dart';
import '../../domain/repositories/economy_repository.dart';

/// [EconomyRepository]'nin gerçek Cloud Firestore implementasyonu.
/// Bakiye `users/{uid}.riskCoin` alanında tutulur; [watchBalance] bu alanı
/// gerçek zamanlı dinler, böylece bakiye başka bir yerden (örn. çok
/// oyunculu sunucu, firebase-admin ile) değiştirildiğinde de anında
/// yansır. [adjustBalance] atomik `FieldValue.increment` kullanır, bu
/// yüzden okuma-değiştirme-yazma yarış durumu oluşmaz.
class FirebaseEconomyRepository implements EconomyRepository {
  FirebaseEconomyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Stream<int> watchBalance(String uid) {
    return _userDoc(uid).snapshots().map((doc) => (doc.data()?['riskCoin'] as num?)?.toInt() ?? 0);
  }

  @override
  Future<void> adjustBalance(String uid, int delta) {
    return _userDoc(uid).update({'riskCoin': FieldValue.increment(delta)});
  }

  @override
  Future<Result<int>> purchasePackage(String uid, int rcAmount) async {
    try {
      await adjustBalance(uid, rcAmount);
      return Success(rcAmount);
    } catch (e) {
      return Failure('Satın alma tamamlanamadı: $e');
    }
  }
}
