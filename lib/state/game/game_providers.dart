import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/cities.dart';
import 'game_notifier.dart';
import 'game_state.dart';

/// Şehir id'sine göre ayrı bir GameNotifier örneği sağlar. `autoDispose`
/// sayesinde oyun masasından çıkıldığında (widget ağacından
/// kaldırıldığında) state otomatik olarak temizlenir, bir sonraki oyun
/// sıfırdan başlar.
final gameNotifierProvider =
    StateNotifierProvider.autoDispose.family<GameNotifier, GameState, String>((ref, cityId) {
  final city = kCities.firstWhere(
    (c) => c.id == cityId,
    orElse: () => kCities.first,
  );
  return GameNotifier(city: city);
});
