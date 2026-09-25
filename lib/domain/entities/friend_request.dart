import 'user_profile.dart';

/// Bekleyen bir arkadaşlık isteği: kimden geldiği (gönderenin profili) ve
/// kabul/red için gereken Firestore doküman id'si.
class IncomingFriendRequest {
  final String requestId;
  final UserProfile fromProfile;

  const IncomingFriendRequest({required this.requestId, required this.fromProfile});
}
