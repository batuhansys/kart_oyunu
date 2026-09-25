import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/utils/logger.dart';
import 'auth_provider.dart';

const int kMaxLevel = 99;

/// L seviyesinden L+1'e geçmek için gereken XP (bkz. server/game/leveling.js
/// xpForLevel - iki taraf da aynı formülü kullanır, sadece burası UI'da
/// ilerleme çubuğu göstermek için).
int xpForLevel(int level) => 1000 * level;

class PendingLevelReward {
  final String id;
  final int level;
  final int rc;
  final String kind; // 'levelup' | 'milestone' | 'maxlevel'

  const PendingLevelReward({
    required this.id,
    required this.level,
    required this.rc,
    required this.kind,
  });

  factory PendingLevelReward.fromMap(Map<String, dynamic> map) {
    return PendingLevelReward(
      id: map['id'] as String? ?? '',
      level: (map['level'] as num?)?.toInt() ?? 0,
      rc: (map['rc'] as num?)?.toInt() ?? 0,
      kind: map['kind'] as String? ?? 'levelup',
    );
  }
}

class LevelState {
  final int level;
  final int xp;
  final bool isRoyalPass;
  final List<PendingLevelReward> pendingRewards;
  final bool isClaiming;
  final String? errorMessage;

  const LevelState({
    this.level = 1,
    this.xp = 0,
    this.isRoyalPass = false,
    this.pendingRewards = const [],
    this.isClaiming = false,
    this.errorMessage,
  });

  bool get isMaxLevel => level >= kMaxLevel;
  int get xpNeededForNext => isMaxLevel ? 0 : xpForLevel(level);
  double get progress => isMaxLevel ? 1.0 : (xp / xpNeededForNext).clamp(0.0, 1.0);

  LevelState copyWith({
    int? level,
    int? xp,
    bool? isRoyalPass,
    List<PendingLevelReward>? pendingRewards,
    bool? isClaiming,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LevelState(
      level: level ?? this.level,
      xp: xp ?? this.xp,
      isRoyalPass: isRoyalPass ?? this.isRoyalPass,
      pendingRewards: pendingRewards ?? this.pendingRewards,
      isClaiming: isClaiming ?? this.isClaiming,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Seviye/XP/Royal Pass/bekleyen ödüller `users/{uid}` dokümanında sunucu
/// tarafından tutulur (bkz. server/game/leveling.js); bu notifier sadece
/// gerçek zamanlı dinler ve ödül toplama isteğini yollar - [walletProvider]
/// ile aynı desen.
class LevelNotifier extends StateNotifier<LevelState> {
  LevelNotifier(this._firestore, this._apiClient, this._uid) : super(const LevelState()) {
    _subscribe();
  }

  final FirebaseFirestore _firestore;
  final ApiClient _apiClient;
  final String? _uid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  void _subscribe() {
    final uid = _uid;
    if (uid == null) return;
    _sub = _firestore.collection('users').doc(uid).snapshots().listen(
      (doc) {
        final data = doc.data();
        if (data == null) return;
        final pendingRaw = data['pendingLevelRewards'] as List<dynamic>? ?? const [];
        state = state.copyWith(
          level: (data['level'] as num?)?.toInt() ?? 1,
          xp: (data['xp'] as num?)?.toInt() ?? 0,
          isRoyalPass: data['isRoyalPass'] as bool? ?? false,
          pendingRewards: pendingRaw
              .map((e) => PendingLevelReward.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList(),
        );
      },
      onError: (Object e) => AppLogger.error('Seviye verisi dinlenemedi: $e'),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> claimRewards() async {
    if (state.pendingRewards.isEmpty || state.isClaiming) return;
    state = state.copyWith(isClaiming: true, clearError: true);
    try {
      await _apiClient.post('/api/level/claim');
      state = state.copyWith(isClaiming: false);
    } on ApiException catch (e) {
      state = state.copyWith(isClaiming: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isClaiming: false, errorMessage: 'Ödül toplanamadı: $e');
    }
  }
}

final levelProvider = StateNotifierProvider<LevelNotifier, LevelState>((ref) {
  final uid = ref.watch(authProvider.select((s) => s.profile?.userId));
  return LevelNotifier(FirebaseFirestore.instance, ref.watch(apiClientProvider), uid);
});
