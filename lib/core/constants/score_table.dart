/// Bir kartın kazandırdığı/kaybettirdiği puanları tutar.
class ScoreEntry {
  final int win;
  final int lose;
  const ScoreEntry({required this.win, required this.lose});
}

/// Kart değerine göre kazanç/kayıp puan tablosu.
///
/// NOT: Kaynak dokümanda birbiriyle çelişen iki farklı puan tablosu
/// (v1 ve v2) yer alıyordu. Burada v2 (daha kapsamlı taslak) esas
/// alınmıştır. Ürün sahibi teyit edince sadece bu haritayı güncellemeniz
/// yeterlidir, kodun başka hiçbir yerine dokunmanıza gerek yoktur.
///
/// Alternatif (v1) değerler referans için:
///   K, Q, J : kazanırsa 20, kaybederse -100
///   10      : kazanırsa 50, kaybederse -50
///   4,5,6   : kazanırsa 100, kaybederse -35
///   3       : kazanırsa 150, kaybederse -20
const Map<int, ScoreEntry> kScoreTable = {
  14: ScoreEntry(win: 0, lose: 0), // A - blöf kartı, kazandırmaz
  13: ScoreEntry(win: 40, lose: -100), // K
  12: ScoreEntry(win: 40, lose: -100), // Q
  11: ScoreEntry(win: 40, lose: -80), // J
  10: ScoreEntry(win: 40, lose: -80),
  9: ScoreEntry(win: 50, lose: -50),
  8: ScoreEntry(win: 50, lose: -50),
  7: ScoreEntry(win: 50, lose: -50),
  6: ScoreEntry(win: 80, lose: -40),
  5: ScoreEntry(win: 80, lose: -40),
  4: ScoreEntry(win: 80, lose: -40),
  3: ScoreEntry(win: 100, lose: -20),
  2: ScoreEntry(win: 0, lose: 0), // 2 - blöf kartı, kaybettirmez
};
