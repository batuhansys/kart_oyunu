import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/logger.dart';
import '../core/utils/result.dart';
import '../data/repositories/firebase_friends_repository.dart';
import '../domain/entities/friend_request.dart';
import '../domain/entities/user_profile.dart';
import 'auth_provider.dart';

class FriendsState {
  final bool isLoading;
  final List<UserProfile> friends;
  final List<IncomingFriendRequest> incomingRequests;
  final String? errorMessage;

  const FriendsState({
    this.isLoading = false,
    this.friends = const [],
    this.incomingRequests = const [],
    this.errorMessage,
  });

  FriendsState copyWith({
    bool? isLoading,
    List<UserProfile>? friends,
    List<IncomingFriendRequest>? incomingRequests,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FriendsState(
      isLoading: isLoading ?? this.isLoading,
      friends: friends ?? this.friends,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final friendsRepositoryProvider = Provider<FirebaseFriendsRepository>((ref) => FirebaseFriendsRepository());

class FriendsNotifier extends StateNotifier<FriendsState> {
  FriendsNotifier(this._repository, this._uid) : super(const FriendsState()) {
    if (_uid != null) refresh();
  }

  final FirebaseFriendsRepository _repository;
  final String? _uid;

  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _repository.fetchFriends(uid),
        _repository.fetchIncomingRequests(uid),
      ]);
      state = state.copyWith(
        isLoading: false,
        friends: results[0] as List<UserProfile>,
        incomingRequests: results[1] as List<IncomingFriendRequest>,
      );
    } catch (e) {
      AppLogger.error('Arkadaş listesi yüklenemedi: $e');
      state = state.copyWith(isLoading: false, errorMessage: 'Arkadaş listesi yüklenemedi.');
    }
  }

  /// Kullanıcı adına göre arayıp bulunan kişiye istek gönderir. Sonucu
  /// (başarı/hata mesajı) çağıran ekrana döner, kendi state'ine yazmaz —
  /// arama diyalog kutusu geçici bir akış, kalıcı state gerektirmiyor.
  Future<Result<void>> searchAndSendRequest(String username) async {
    final uid = _uid;
    if (uid == null) return const Failure('Giriş yapmalısınız.');

    try {
      final searchResult = await _repository.searchByUsername(username);
      if (searchResult is Failure<UserProfile>) return Failure(searchResult.message);

      final profile = (searchResult as Success<UserProfile>).value;
      return await _repository.sendRequest(myUid: uid, targetUid: profile.userId);
    } catch (e, st) {
      AppLogger.error('searchAndSendRequest başarısız: $e\n$st');
      return Failure('Hata: $e');
    }
  }

  Future<void> respond(String requestId, {required bool accept}) async {
    await _repository.respondToRequest(requestId: requestId, accept: accept);
    await refresh();
  }

  Future<void> removeFriend(String friendUid) async {
    final uid = _uid;
    if (uid == null) return;
    await _repository.removeFriend(myUid: uid, friendUid: friendUid);
    await refresh();
  }
}

final friendsProvider = StateNotifierProvider<FriendsNotifier, FriendsState>((ref) {
  final uid = ref.watch(authProvider.select((s) => s.profile?.userId));
  return FriendsNotifier(ref.watch(friendsRepositoryProvider), uid);
});
