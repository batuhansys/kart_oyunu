import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/utils/logger.dart';
import 'auth_provider.dart';

/// server/game/workshop.js ile ayni.
const int kFragmentsPerChest = 5;
const int kMaxFragmentsPerCity = 50;

/// Bir şehir için sahip olunan parça ve sandık sayısı.
class CityInventory {
  final int fragments;
  final int chests;

  const CityInventory({this.fragments = 0, this.chests = 0});
}

/// Bir sandık açıldığında dönen sonuç - UI'ın gösterdiği ödül diyaloğu
/// için (bkz. workshop_screen.dart).
class ChestOpenResult {
  final String rewardType; // 'rc' | 'power'
  final int? rc;
  final String? power; // 'zorba' | 'kalkan' | 'kahin'

  const ChestOpenResult({required this.rewardType, this.rc, this.power});
}

class WorkshopState {
  final Map<String, CityInventory> inventories;
  final bool isBusy;
  final String? errorMessage;

  const WorkshopState({this.inventories = const {}, this.isBusy = false, this.errorMessage});

  CityInventory forCity(String cityId) => inventories[cityId] ?? const CityInventory();

  WorkshopState copyWith({
    Map<String, CityInventory>? inventories,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WorkshopState(
      inventories: inventories ?? this.inventories,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Şehir parçaları/sandıkları `users/{uid}` üzerinde sunucu tarafından
/// tutulur (bkz. server/game/workshop.js); bir şehirde galibiyet parça
/// kazandırır (sadece şehir kuyruğu maçında, bkz. room.js), birleştirme
/// ve sandık açma REST üzerinden sunucuda işlenir.
class WorkshopNotifier extends StateNotifier<WorkshopState> {
  WorkshopNotifier(this._firestore, this._apiClient, this._uid) : super(const WorkshopState()) {
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
        final fragments = Map<String, dynamic>.from(data['fragments'] as Map? ?? {});
        final chests = Map<String, dynamic>.from(data['chests'] as Map? ?? {});
        final cityIds = {...fragments.keys, ...chests.keys};
        final inventories = <String, CityInventory>{
          for (final id in cityIds)
            id: CityInventory(
              fragments: (fragments[id] as num?)?.toInt() ?? 0,
              chests: (chests[id] as num?)?.toInt() ?? 0,
            ),
        };
        state = state.copyWith(inventories: inventories);
      },
      onError: (Object e) => AppLogger.error('Atölye verisi dinlenemedi: $e'),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> mergeFragments(String cityId) async {
    if (state.isBusy) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _apiClient.post('/api/workshop/merge', body: {'cityId': cityId});
      state = state.copyWith(isBusy: false);
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isBusy: false, errorMessage: 'Birleştirme başarısız: $e');
    }
  }

  Future<ChestOpenResult?> openChest(String cityId) async {
    if (state.isBusy) return null;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await _apiClient.post('/api/workshop/open-chest', body: {'cityId': cityId});
      state = state.copyWith(isBusy: false);
      return ChestOpenResult(
        rewardType: result['rewardType'] as String,
        rc: (result['rc'] as num?)?.toInt(),
        power: result['power'] as String?,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(isBusy: false, errorMessage: 'Sandık açılamadı: $e');
      return null;
    }
  }
}

final workshopProvider = StateNotifierProvider<WorkshopNotifier, WorkshopState>((ref) {
  final uid = ref.watch(authProvider.select((s) => s.profile?.userId));
  return WorkshopNotifier(FirebaseFirestore.instance, ref.watch(apiClientProvider), uid);
});
