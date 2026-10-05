/**
 * 101 Okey taslari. 106 tas: 4 renk x 1..13 x 2 kopya = 104 + 2 sahte okey.
 * Tas = { id, color (0-3), number (1-13), fake }. Sahte okey'in color/number
 * alani anlamsizdir (-1/0): oyunda "okey tasinin kendisi" gibi davranir.
 *
 * Gosterge: destenin ustunden acilan tas. Okey = ayni renkte bir sonraki sayi
 * (13'un okey'i 1). Okey taslari (gercek) joker gibi her tasin yerine gecer.
 */
const COLOR_COUNT = 4;
const MAX_NUMBER = 13;

function buildDeck() {
  const tiles = [];
  let id = 0;
  for (let copy = 0; copy < 2; copy++) {
    for (let color = 0; color < COLOR_COUNT; color++) {
      for (let number = 1; number <= MAX_NUMBER; number++) {
        tiles.push({ id: id++, color, number, fake: false });
      }
    }
  }
  tiles.push({ id: id++, color: -1, number: 0, fake: true });
  tiles.push({ id: id++, color: -1, number: 0, fake: true });
  return tiles;
}

function shuffle(array, rng = Math.random) {
  const a = array.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Gostergeye gore okey yuzu (renk + sayi). */
function okeyFaceFor(indicator) {
  return { color: indicator.color, number: (indicator.number % MAX_NUMBER) + 1 };
}

/** Gercek okey (joker) mi? Sahte okey joker DEGILDIR. */
function isJoker(tile, okey) {
  return !tile.fake && tile.color === okey.color && tile.number === okey.number;
}

/** Tasin "yuzu": sahte okey okey yuzunu tasir; joker icin null (her sey olabilir). */
function faceOf(tile, okey) {
  if (isJoker(tile, okey)) return null;
  if (tile.fake) return { color: okey.color, number: okey.number };
  return { color: tile.color, number: tile.number };
}

module.exports = { COLOR_COUNT, MAX_NUMBER, buildDeck, shuffle, okeyFaceFor, isJoker, faceOf };
