import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/utils/logger.dart';
import 'auth_provider.dart';

/// server/game/dailyWheel.js ile birebir ayni - sadece UI'da odul
/// onizlemesi/dilim etiketleri icin kullanilir, GERCEK sonuc her zaman
/// sunucudan gelir (bkz. DailyWheelNotifier.spin).
const List<double> kWheelTierPercents = [0.01, 0.02, 0.04, 0.10, 0.20, 0.50];
const int kWheelMinBaseRc = 10000;

class WheelSpinResult {
  final int tierIndex;
  final int rewardRc;
  const WheelSpinResult({required this.tierIndex, required this.rewardRc});
}

class DailyWheelState {
  final DateTime? lastFreeSpinAt;
  final DateTime? lastAdSpinAt;
  final bool isSpinning;
  final String? errorMessage;

  const DailyWheelState({
    this.lastFreeSpinAt,
    this.lastAdSpinAt,
    this.isSpinning = false,
    this.errorMessage,
  });

  static bool _isToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now().toUtc();
    final u = d.toUtc();
    return u.year == now.year && u.month == now.month && u.day == now.day;
  }

  bool get freeAvailable => !_isToday(lastFreeSpinAt);
  bool get adAvailable => _isToday(lastFreeSpinAt) && !_isToday(lastAdSpinAt);

  DailyWheelState copyWith({
    DateTime? lastFreeSpinAt,
    DateTime? lastAdSpinAt,
    bool? isSpinning,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DailyWheelState(
      lastFreeSpinAt: lastFreeSpinAt ?? this.lastFreeSpinAt,
      lastAdSpinAt: lastAdSpinAt ?? this.lastAdSpinAt,
      isSpinning: isSpinning ?? this.isSpinning,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Son ücretsiz/reklamlı çevirme zamanları `users/{uid}` üzerinde sunucu
/// tarafından tutulur; bu notifier sadece gerçek zamanlı dinler ve
/// çevirme isteğini yollar (walletProvider/levelProvider ile aynı desen).
class DailyWheelNotifier extends StateNotifier<DailyWheelState> {
  DailyWheelNotifier(this._firestore, this._apiClient, this._uid) : super(const DailyWheelState()) {
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
        state = state.copyWith(
          lastFreeSpinAt: (data['lastFreeSpinAt'] as Timestamp?)?.toDate(),
          lastAdSpinAt: (data['lastAdSpinAt'] as Timestamp?)?.toDate(),
        );
      },
      onError: (Object e) => AppLogger.error('Çark verisi dinlenemedi: $e'),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<WheelSpinResult?> spin(String type) async {
    if (state.isSpinning) return null;
    state = state.copyWith(isSpinning: true, clearError: true);
    try {
      final result = await _apiClient.post('/api/wheel/spin', body: {'type': type});
      state = state.copyWith(isSpinning: false);
      return WheelSpinResult(
        tierIndex: (result['tierIndex'] as num).toInt(),
        rewardRc: (result['rewardRc'] as num).toInt(),
      );
    } on ApiException catch (e) {
      state = state.copyWith(isSpinning: false, errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(isSpinning: false, errorMessage: 'Çark çevrilemedi: $e');
      return null;
    }
  }
}

final dailyWheelProvider = StateNotifierProvider<DailyWheelNotifier, DailyWheelState>((ref) {
  final uid = ref.watch(authProvider.select((s) => s.profile?.userId));
  return DailyWheelNotifier(FirebaseFirestore.instance, ref.watch(apiClientProvider), uid);
});
