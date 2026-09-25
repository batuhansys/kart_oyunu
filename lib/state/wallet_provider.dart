import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/logger.dart';
import '../data/repositories/firebase_economy_repository.dart';
import '../domain/repositories/economy_repository.dart';
import 'auth_provider.dart';

class WalletState {
  final int riskCoin;
  final bool isPurchasing;
  final String? errorMessage;

  const WalletState({
    this.riskCoin = 0,
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

final economyRepositoryProvider = Provider<EconomyRepository>((ref) => FirebaseEconomyRepository());

/// Bakiye artik `users/{uid}.riskCoin` dokumaninda kalici olarak tutulur.
/// [WalletNotifier], giris yapan kullanicinin uid'ine baglanip Firestore'u
/// gercek zamanli dinler; deduct/add ise once yerel state'i iyimser
/// (optimistic) guncelleyip ardindan Firestore'a yazar — kisa sureli agdaki
/// gecikmede bile ekran hemen tepki verir, sonrasinda dinleyici gercek
/// degerle senkronlar.
class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier(this._repository, this._uid) : super(const WalletState()) {
    _subscribe();
  }

  final EconomyRepository _repository;
  final String? _uid;
  StreamSubscription<int>? _sub;

  void _subscribe() {
    final uid = _uid;
    if (uid == null) return;
    _sub = _repository.watchBalance(uid).listen(
      (balance) => state = state.copyWith(riskCoin: balance),
      onError: (Object e) => AppLogger.error('Bakiye dinlenemedi: $e'),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool canAfford(int amount) => state.riskCoin >= amount;

  void deduct(int amount) {
    state = state.copyWith(riskCoin: state.riskCoin - amount);
    final uid = _uid;
    if (uid != null) _repository.adjustBalance(uid, -amount);
  }

  void add(int amount) {
    state = state.copyWith(riskCoin: state.riskCoin + amount);
    final uid = _uid;
    if (uid != null) _repository.adjustBalance(uid, amount);
  }

  Future<void> purchasePackage(int amount) async {
    final uid = _uid;
    if (uid == null) return;
    state = state.copyWith(isPurchasing: true, clearError: true);
    final result = await _repository.purchasePackage(uid, amount);
    result.when(
      success: (_) {
        state = state.copyWith(isPurchasing: false);
      },
      failure: (message) {
        AppLogger.error('Satın alma başarısız: $message');
        state = state.copyWith(isPurchasing: false, errorMessage: message);
      },
    );
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final uid = ref.watch(authProvider.select((s) => s.profile?.userId));
  return WalletNotifier(ref.watch(economyRepositoryProvider), uid);
});
