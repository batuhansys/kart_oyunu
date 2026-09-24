import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir şehir için sahip olunan parça ve sandık sayısını tutar.
class CityInventory {
  final int fragments;
  final int chests;

  const CityInventory({this.fragments = 0, this.chests = 0});

  CityInventory copyWith({int? fragments, int? chests}) {
    return CityInventory(
      fragments: fragments ?? this.fragments,
      chests: chests ?? this.chests,
    );
  }
}

/// Bir şehirde galibiyet kazanıldığında o şehrin parçası kazanılır.
/// Yeterli parça (kFragmentsPerChest) birleştirilince bir sandığa
/// dönüşür; sandık açılınca rastgele bir Risk Coin ödülü verir.
///
/// NOT: Uygulamada henüz kalıcı depolama yok, bu envanter de diğer
/// tüm state gibi sadece uygulama açıkken tutulur.
class WorkshopState {
  final Map<String, CityInventory> inventories;

  const WorkshopState({this.inventories = const {}});

  CityInventory forCity(String cityId) => inventories[cityId] ?? const CityInventory();

  WorkshopState copyWith({Map<String, CityInventory>? inventories}) {
    return WorkshopState(inventories: inventories ?? this.inventories);
  }
}

const int kFragmentsPerChest = 5;
const int kChestRewardMin = 100;
const int kChestRewardMax = 1000;

class WorkshopNotifier extends StateNotifier<WorkshopState> {
  final Random _random;

  WorkshopNotifier({Random? random}) : _random = random ?? Random(), super(const WorkshopState());

  void addFragment(String cityId) {
    final current = state.forCity(cityId);
    _setCity(cityId, current.copyWith(fragments: current.fragments + 1));
  }

  bool canMerge(String cityId) => state.forCity(cityId).fragments >= kFragmentsPerChest;

  void mergeFragments(String cityId) {
    final current = state.forCity(cityId);
    if (current.fragments < kFragmentsPerChest) return;
    _setCity(
      cityId,
      current.copyWith(
        fragments: current.fragments - kFragmentsPerChest,
        chests: current.chests + 1,
      ),
    );
  }

  bool canOpen(String cityId) => state.forCity(cityId).chests > 0;

  /// Sandığı açar ve kazanılan Risk Coin miktarını döndürür (0 ise
  /// açılacak sandık yoktu demektir).
  int openChest(String cityId) {
    final current = state.forCity(cityId);
    if (current.chests <= 0) return 0;
    _setCity(cityId, current.copyWith(chests: current.chests - 1));
    return kChestRewardMin + _random.nextInt(kChestRewardMax - kChestRewardMin + 1);
  }

  void _setCity(String cityId, CityInventory inventory) {
    state = state.copyWith(inventories: {...state.inventories, cityId: inventory});
  }
}

final workshopProvider = StateNotifierProvider<WorkshopNotifier, WorkshopState>((ref) {
  return WorkshopNotifier();
});
