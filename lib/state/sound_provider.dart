import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/sound_service.dart';

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = AudioPlayersSoundService();
  ref.onDispose(service.dispose);
  return service;
});
