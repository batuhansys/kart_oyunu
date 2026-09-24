import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/logger.dart';
import '../data/repositories/local_economy_repository.dart';
import '../domain/repositories/economy_repository.dart';

class WalletState {
  final int riskCoin;
  final bool isPurchasing;
  final String? errorMessage;

  const WalletState({
    this.riskCoin = 1000, // yeni hesap başlangıç bakiyesi
    this.isPurchasing = false,
    this.errorMessage,
  });

  WalletState copyWith({
    int? riskCoin,
    bool? isPurchasing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WalletState(
      riskCoin: riskCoin ?? this.riskCoin,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final economyRepositoryProvider = Provider<EconomyRepository>((ref) => LocalEconomyRepository());

class WalletNotifier extends StateNotifier<WalletState> {
  final EconomyRepository _repository;

  WalletNotifier(this._repository) : super(const WalletState());

  bool canAfford(int amount) => state.riskCoin >= amount;

  void deduct(int amount) {
    state = state.copyWith(riskCoin: state.riskCoin - amount);
  }

  void add(int amount) {
    state = state.copyWith(riskCoin: state.riskCoin + amount);
  }

  Future<void> purchasePackage(int amount) async {
    state = state.copyWith(isPurchasing: true, clearError: true);
    final result = await _repository.purchasePackage(amount);
    result.when(
      success: (granted) {
        state = state.copyWith(riskCoin: state.riskCoin + granted, isPurchasing: false);
      },
      failure: (message) {
        AppLogger.error('Satın alma başarısız: $message');
        state = state.copyWith(isPurchasing: false, errorMessage: message);
      },
    );
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref.watch(economyRepositoryProvider));
});
