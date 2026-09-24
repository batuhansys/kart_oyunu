/// Bir elde oyuncunun yapabileceği üç tercih. Domain katmanında yer
/// alır çünkü oyunun temel bir kavramıdır (belirli bir state
/// management veya UI implementasyonuna bağlı değildir).
/// `timeout`: oyuncu karar süresi içinde bir tercih yapmadığında
/// otomatik olarak atanır (bkz. GameNotifier.handleTimeout). Puanlama
/// kuralı: kart kazanır olsa dahi puan getirmez, kaybeden bir kartsa
/// çifte riskin ceza puanını alır (bkz. ScoringService).
enum PlayerChoice { risk, doubleRisk, pass, timeout }

/// UI'da tercihi kısa bir etiket olarak göstermek için (örn. oyun
/// geçmişi paneli).
extension PlayerChoiceLabel on PlayerChoice {
  String get shortLabel {
    switch (this) {
      case PlayerChoice.risk:
        return 'Risk';
      case PlayerChoice.doubleRisk:
        return 'Çifte Risk';
      case PlayerChoice.pass:
        return 'Pas';
      case PlayerChoice.timeout:
        return 'Süre Doldu';
    }
  }

  /// Coklu oyunculu sunucuya gonderilen tel (wire) formatı — sadece
  /// kullanıcının bilinçli tercih edebildiği degerler icin anlamlıdır.
  /// `timeout` istemciden asla gonderilmez, sunucu kendi süresi dolunca
  /// bu degeri kendisi atar (bkz. server/game/room.js _onRoundTimeout).
  String get wireValue {
    switch (this) {
      case PlayerChoice.risk:
        return 'risk';
      case PlayerChoice.doubleRisk:
        return 'doubleRisk';
      case PlayerChoice.pass:
        return 'pass';
      case PlayerChoice.timeout:
        throw StateError('timeout istemciden gonderilemez');
    }
  }
}

/// Sunucudan gelen `round_result` gibi olaylardaki tel (wire) degerini
/// (`risk` | `doubleRisk` | `pass` | `timeout`) enum'a cevirir.
PlayerChoice playerChoiceFromWire(String value) {
  switch (value) {
    case 'risk':
      return PlayerChoice.risk;
    case 'doubleRisk':
      return PlayerChoice.doubleRisk;
    case 'pass':
      return PlayerChoice.pass;
    case 'timeout':
      return PlayerChoice.timeout;
    default:
      throw ArgumentError('Bilinmeyen PlayerChoice degeri: $value');
  }
}
