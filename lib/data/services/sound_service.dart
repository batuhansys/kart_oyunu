import 'package:audioplayers/audioplayers.dart';

import '../../core/utils/logger.dart';

/// Oyun içi ses efektlerini yönetir.
///
/// NOT: Bu sürümde gerçek ses dosyaları (assets/sounds/ altında)
/// projeye eklenmemiştir; bu sınıf ve arayüzü hazır bir mimari sağlar.
/// Ses dosyalarını ekleyip pubspec.yaml'daki `assets:` bölümünü
/// açtığınızda aşağıdaki metodlar otomatik olarak çalışmaya başlar.
/// Dosya bulunamazsa hata sessizce loglanır, UYGULAMA ÇÖKMEZ.
abstract class SoundService {
  Future<void> playClick();
  Future<void> playCardFlip();
  Future<void> playWin();
  Future<void> playLose();
  Future<void> playCoin();
  void dispose();
}

/// [SoundService]'in audioplayers paketiyle gerçek implementasyonu.
/// Üst üste binen sesler (örn. hızlı tıklamalar) için küçük bir
/// AudioPlayer havuzu kullanılır.
class AudioPlayersSoundService implements SoundService {
  final List<AudioPlayer> _pool = List.generate(3, (_) => AudioPlayer());
  int _next = 0;

  AudioPlayer get _player {
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    return player;
  }

  Future<void> _play(String assetPath) async {
    try {
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      AppLogger.warning('Ses çalınamadı ($assetPath): $e');
    }
  }

  @override
  Future<void> playClick() => _play('sounds/click.mp3');

  @override
  Future<void> playCardFlip() => _play('sounds/card_flip.mp3');

  @override
  Future<void> playWin() => _play('sounds/win.mp3');

  @override
  Future<void> playLose() => _play('sounds/lose.mp3');

  @override
  Future<void> playCoin() => _play('sounds/coin.mp3');

  @override
  void dispose() {
    for (final player in _pool) {
      player.dispose();
    }
  }
}
