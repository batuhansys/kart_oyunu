import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/logger.dart';
import 'auth_provider.dart';

/// server/game/powerups.js ile ayni: bir sandiktan kazanilan guc, suresi
/// gecmemis mevcut adede eklenir ve gecerlilik suresini yeniler. Suresi
/// gecmis bir adet kullanilamaz (usableCount 0 doner).
class PowerCount {
  final int count;
  final DateTime? expiresAt;

  const PowerCount({this.count = 0, this.expiresAt});

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  int get usableCount => isExpired ? 0 : count;

  Duration? get remaining =>
      isExpired || expiresAt == null ? null : expiresAt!.difference(DateTime.now());
}

class PowerInventoryState {
  final PowerCount zorba;
  final PowerCount kalkan;
  final PowerCount kahin;

  const PowerInventoryState({
    this.zorba = const PowerCount(),
    this.kalkan = const PowerCount(),
    this.kahin = const PowerCount(),
  });

  PowerInventoryState copyWith({PowerCount? zorba, PowerCount? kalkan, PowerCount? kahin}) {
    return PowerInventoryState(
      zorba: zorba ?? this.zorba,
      kalkan: kalkan ?? this.kalkan,
      kahin: kahin ?? this.kahin,
    );
  }
}

/// Guc envanteri (ZORBA/KALKAN/KAHIN adet + kalan sure) `users/{uid}`
/// dokumaninda sunucu tarafindan tutulur (bkz. server/game/workshop.js
/// openChest); bu notifier sadece gerçek zamanlı dinler - walletProvider
/// ile ayni desen.
class PowerInventoryNotifier extends StateNotifier<PowerInventoryState> {
  PowerInventoryNotifier(this._firestore, this._uid) : super(const PowerInventoryState()) {
    _subscribe();
  }

  final FirebaseFirestore _firestore;
  final String? _uid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  PowerCount _parse(Map<String, dynamic>? powerups, String key) {
    final raw = powerups?[key];
    if (raw == null) return const PowerCount();
    final map = Map<String, dynamic>.from(raw as Map);
    return PowerCount(
      count: (map['count'] as num?)?.toInt() ?? 0,
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  void _subscribe() {
    final uid = _uid;
    if (uid == null) return;
    _sub = _firestore.collection('users').doc(uid).snapshots().listen(
      (doc) {
        final data = doc.data();
        final powerups = data?['powerups'] as Map<String, dynamic>?;
        state = state.copyWith(
          zorba: _parse(powerups, 'zorba'),
          kalkan: _parse(powerups, 'kalkan'),
          kahin: _parse(powerups, 'kahin'),
        );
      },
      onError: (Object e) => AppLogger.error('Güç envanteri dinlenemedi: $e'),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final powerInventoryProvider = StateNotifierProvider<PowerInventoryNotifier, PowerInventoryState>((ref) {
  final uid = ref.watch(authProvider.select((s) => s.profile?.userId));
  return PowerInventoryNotifier(FirebaseFirestore.instance, uid);
});
