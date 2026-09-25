import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/result.dart';
import '../../domain/entities/friend_request.dart';
import '../../domain/entities/user_profile.dart';

/// Arkadaşlık istekleri Firestore'da `friendRequests/{aUid_bUid}` (uid'ler
/// alfabetik sıralanmış) dokümanında tutulur — bu, aynı iki kullanıcı
/// arasında birden fazla istek dokümanı oluşmasını (ve karmaşık "zaten
/// var mı" sorgularını) baştan imkansız kılar. Arkadaş listesi ayrı bir
/// alan/koleksiyon olarak SAKLANMAZ: `status == 'accepted'` olan
/// isteklerin kendisi arkadaşlık kaydının tek doğru kaynağıdır (bkz.
/// [watchFriends]) — bu sayede kabul islemi tek bir dokuman guncellemesi
/// olur, iki farkli kullanicinin dokumanina birden yazma (ve bunun icin
/// bir sunucu araciligi) gerekmez.
class FirebaseFriendsRepository {
  FirebaseFriendsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String _requestId(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  UserProfile _profileFromDoc(String uid, Map<String, dynamic> data) {
    return UserProfile(
      username: data['username'] as String? ?? 'Oyuncu',
      userId: uid,
      level: (data['level'] as num?)?.toInt() ?? 1,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
    );
  }

  /// Tam kullanıcı adıyla arar (büyük/küçük harf duyarsız). Kısmi/prefix
  /// arama Firestore'da ekstra indeksleme gerektirir; MVP kapsamında tam
  /// eşleşme yeterlidir.
  Future<Result<UserProfile>> searchByUsername(String username) async {
    final lower = username.trim().toLowerCase();
    if (lower.isEmpty) return const Failure('Kullanıcı adı boş olamaz.');

    final usernameDoc = await _firestore.collection('usernames').doc(lower).get();
    if (!usernameDoc.exists) return const Failure('Bu kullanıcı adında biri bulunamadı.');

    final uid = usernameDoc.data()!['uid'] as String;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return const Failure('Kullanıcı bulunamadı.');

    return Success(_profileFromDoc(uid, userDoc.data()!));
  }

  Future<Result<void>> sendRequest({required String myUid, required String targetUid}) async {
    if (myUid == targetUid) return const Failure('Kendine arkadaşlık isteği gönderemezsin.');

    final ref = _firestore.collection('friendRequests').doc(_requestId(myUid, targetUid));
    final existing = await ref.get();
    if (existing.exists) {
      final status = existing.data()!['status'] as String;
      return Failure(status == 'accepted' ? 'Zaten arkadaşsınız.' : 'Bu kullanıcıya zaten bir istek gönderilmiş.');
    }

    await ref.set({
      'fromUid': myUid,
      'toUid': targetUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return const Success(null);
  }

  Future<Result<void>> respondToRequest({required String requestId, required bool accept}) async {
    await _firestore.collection('friendRequests').doc(requestId).update({
      'status': accept ? 'accepted' : 'declined',
    });
    return const Success(null);
  }

  Future<List<IncomingFriendRequest>> fetchIncomingRequests(String myUid) async {
    final snap = await _firestore
        .collection('friendRequests')
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .get();

    final requests = <IncomingFriendRequest>[];
    for (final doc in snap.docs) {
      final fromUid = doc.data()['fromUid'] as String;
      final fromDoc = await _firestore.collection('users').doc(fromUid).get();
      if (!fromDoc.exists) continue;
      requests.add(IncomingFriendRequest(
        requestId: doc.id,
        fromProfile: _profileFromDoc(fromUid, fromDoc.data()!),
      ));
    }
    return requests;
  }

  Future<List<UserProfile>> fetchFriends(String myUid) async {
    final sentAccepted = await _firestore
        .collection('friendRequests')
        .where('fromUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'accepted')
        .get();
    final receivedAccepted = await _firestore
        .collection('friendRequests')
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'accepted')
        .get();

    final friendUids = <String>{
      ...sentAccepted.docs.map((d) => d.data()['toUid'] as String),
      ...receivedAccepted.docs.map((d) => d.data()['fromUid'] as String),
    };

    final profiles = <UserProfile>[];
    for (final uid in friendUids) {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) profiles.add(_profileFromDoc(uid, doc.data()!));
    }
    return profiles;
  }
}
