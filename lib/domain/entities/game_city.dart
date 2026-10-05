/// Oyuna giriş yapılabilecek bir şehri temsil eder.
class GameCity {
  final String id;
  final String name;
  final int entryFee;

  const GameCity({
    required this.id,
    required this.name,
    required this.entryFee,
  });

  /// 101 Okey: masada 1. olan giriş ücretinin 2.4 katını kazanır, 2. olan
  /// ücretini geri alır (bkz. server/okey/room.js PRIZE_MULT).
  int get rewardAmount => (entryFee * 2.4).round();

  /// Sunucudan (server/game/cities.js) gelen `{id, name, entryFee}`
  /// haritasını ayrıştırır — çok oyunculu maç/oda olaylarında kullanılır.
  factory GameCity.fromJson(Map<String, dynamic> json) {
    return GameCity(
      id: json['id'] as String,
      name: json['name'] as String,
      entryFee: (json['entryFee'] as num).toInt(),
    );
  }
}
