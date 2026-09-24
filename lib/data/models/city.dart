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

  /// Kural: kazanç her zaman giriş ücretinin 2 katıdır.
  int get rewardAmount => entryFee * 2;
}
