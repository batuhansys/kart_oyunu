// Flutter tarafındaki lib/core/constants/game_constants.dart ve
// score_table.dart ile birebir aynı değerler. Buradaki kurallar
// oyunun "tek dogru kaynagi" (source of truth) sayilir; Flutter
// istemcisi sadece gorsellestirir, puanlama ve zaman asimi kararini
// her zaman bu sunucu verir.

const WIN_SCORE_THRESHOLD = 250;
const LOSE_SCORE_THRESHOLD = -250;

// Art arda en fazla kac kez pas gecilebilir (3. elde zorunlu risk kurali).
const MAX_CONSECUTIVE_PASSES = 2;

// Karar suresi (saniye). Sunucu bu sureyi kendi zamanlayicisiyla
// zorunlu kilar; istemcideki gorsel sayac sadece animasyon icindir.
const DECISION_SECONDS = 7;

// Bir el sonuclandiktan sonra yeni elin dagitilmasindan once beklenen sure.
const RESULT_DISPLAY_SECONDS = 3;

const SUITS = ['spades', 'hearts', 'diamonds', 'clubs'];
const RANKS = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];

// rank -> { win, lose } puan tablosu (score_table.dart ile ayni).
const SCORE_TABLE = {
  14: { win: 0, lose: 0 }, // A - blof karti, kazandirmaz
  13: { win: 40, lose: -100 }, // K
  12: { win: 40, lose: -100 }, // Q
  11: { win: 40, lose: -80 }, // J
  10: { win: 40, lose: -80 },
  9: { win: 50, lose: -50 },
  8: { win: 50, lose: -50 },
  7: { win: 50, lose: -50 },
  6: { win: 80, lose: -40 },
  5: { win: 80, lose: -40 },
  4: { win: 80, lose: -40 },
  3: { win: 100, lose: -20 },
  2: { win: 0, lose: 0 }, // 2 - blof karti, kaybettirmez
};

module.exports = {
  WIN_SCORE_THRESHOLD,
  LOSE_SCORE_THRESHOLD,
  MAX_CONSECUTIVE_PASSES,
  DECISION_SECONDS,
  RESULT_DISPLAY_SECONDS,
  SUITS,
  RANKS,
  SCORE_TABLE,
};
