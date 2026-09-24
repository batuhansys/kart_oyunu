import 'package:flutter_test/flutter_test.dart';
import 'package:risk_get_and_gain/domain/entities/game_city.dart';
import 'package:risk_get_and_gain/domain/entities/player_choice.dart';
import 'package:risk_get_and_gain/state/game/game_notifier.dart';
import 'package:risk_get_and_gain/state/game/game_state.dart';

/// NOT: Bu testler bilinçli olarak tek bir el ile sınırlı tutulmuştur.
/// Bunun nedeni: gerçek rastgeleliği kullanan çok-elli senaryolar (ör.
/// "3. elde zorunlu risk kuralı") arka arkaya birkaç el boyunca
/// yapay zekanın kötü sonuçlar alıp erken oyunu bitirmesi ihtimaliyle
/// (düşük de olsa) test'i zaman zaman kırılgan (flaky) hale
/// getirebilir. Böyle çok-elli senaryoları güvenilir şekilde test
/// etmek için GameNotifier'a sabit tohumlu (seeded) bir Random
/// enjekte edip `fake_async` gibi bir paketle zamanı simüle etmek
/// önerilir — bu, projeye eklenebilecek iyi bir sonraki adımdır.
void main() {
  const city = GameCity(id: 'test', name: 'Test Şehri', entryFee: 100);

  test('rewardIfWon giriş ücretinin 2 katıdır', () {
    final notifier = GameNotifier(city: city);
    expect(notifier.rewardIfWon, 200);
    notifier.dispose();
  });

  test('yeni oyun waitingForChoices fazıyla ve boş tercihlerle başlar', () {
    final notifier = GameNotifier(city: city);
    expect(notifier.state.phase, GamePhase.waitingForChoices);
    expect(notifier.state.userChoice, isNull);
    expect(notifier.state.userScore, 0);
    expect(notifier.state.aiScore, 0);
    expect(notifier.canUserPass, isTrue);
    notifier.dispose();
  });

  test('kullanıcı pas geçince ardışık pas sayacı artar', () {
    final notifier = GameNotifier(city: city);
    notifier.submitUserChoice(PlayerChoice.pass);
    expect(notifier.state.userConsecutivePasses, 1);
    notifier.dispose();
  });

  test('faz waitingForChoices değilken submitUserChoice yok sayılır', () {
    final notifier = GameNotifier(city: city);
    notifier.submitUserChoice(PlayerChoice.risk);
    // İlk tercih verildikten sonra faz artık waitingForChoices değildir
    // (revealing/scoring/gameOver olabilir); ikinci bir tercih çağrısı
    // hiçbir şeyi değiştirmemelidir.
    final phaseAfterFirst = notifier.state.phase;
    final userScoreAfterFirst = notifier.state.userScore;
    notifier.submitUserChoice(PlayerChoice.doubleRisk);
    expect(notifier.state.phase, phaseAfterFirst);
    expect(notifier.state.userScore, userScoreAfterFirst);
    notifier.dispose();
  });

  test('dispose sonrası metod çağrıları hataya yol açmaz', () {
    final notifier = GameNotifier(city: city);
    notifier.dispose();
    expect(() => notifier.handleTimeout(), returnsNormally);
    expect(() => notifier.submitUserChoice(PlayerChoice.pass), returnsNormally);
  });
}
