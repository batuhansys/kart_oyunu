const test = require('node:test');
const assert = require('node:assert');
const { analyzeMeld, solveMelds, maxPairs, canOpen } = require('../okey/melds');
const { OkeyGame } = require('../okey/game');
const { buildDeck } = require('../okey/tiles');

// Okey = mavi(1) 5 (renk 1, sayi 5). Sahte okey id 104/105.
const OKEY = { color: 1, number: 5 };
let nextId = 1000;
const T = (color, number) => ({ id: nextId++, color, number, fake: false });
const JOKER = () => T(OKEY.color, OKEY.number);
const FAKE = () => ({ id: nextId++, color: -1, number: 0, fake: true });

test('grup: ayni sayi farkli renk', () => {
  const a = analyzeMeld([T(0, 7), T(2, 7), T(3, 7)], OKEY);
  assert.strictEqual(a.type, 'group');
  assert.strictEqual(a.value, 21);
  assert.strictEqual(analyzeMeld([T(0, 7), T(0, 7), T(3, 7)], OKEY), null);
  assert.strictEqual(analyzeMeld([T(0, 7), T(1, 7), T(2, 7), T(3, 7), T(0, 7)], OKEY), null);
});

test('seri: ardisik ayni renk, 12-13-1 gecerli, 13-1-2 gecersiz', () => {
  assert.strictEqual(analyzeMeld([T(0, 3), T(0, 4), T(0, 6)], OKEY), null);
  const r = analyzeMeld([T(0, 8), T(0, 9), T(0, 10)], OKEY);
  assert.strictEqual(r.type, 'run');
  assert.strictEqual(r.value, 27);
  const wrap = analyzeMeld([T(2, 12), T(2, 13), T(2, 1)], OKEY);
  assert.ok(wrap && wrap.type === 'run');
  assert.strictEqual(wrap.value, 12 + 13 + 1);
  assert.strictEqual(analyzeMeld([T(2, 13), T(2, 1), T(2, 2)], OKEY), null);
});

test('joker serideki bosluga ve uca gecer, puan en yuksek secimle', () => {
  const gap = analyzeMeld([T(0, 8), JOKER(), T(0, 10)], OKEY);
  assert.strictEqual(gap.value, 27);
  const edge = analyzeMeld([T(0, 8), T(0, 9), JOKER()], OKEY);
  assert.strictEqual(edge.value, 8 + 9 + 10); // 10 olarak sayilir (7'den yuksek)
  const grp = analyzeMeld([T(0, 9), T(1, 9), JOKER()], OKEY);
  assert.strictEqual(grp.value, 27);
});

test('sahte okey okey tasinin yuzunu tasir', () => {
  // okey = mavi 5: sahte okey mavi 5 gibi davranir
  const a = analyzeMeld([T(1, 4), FAKE(), T(1, 6)], OKEY);
  assert.ok(a && a.type === 'run');
  assert.strictEqual(a.value, 15);
});

test('cift: ayni tas veya joker', () => {
  assert.ok(analyzeMeld([T(0, 5), T(0, 5)], OKEY));
  assert.strictEqual(analyzeMeld([T(0, 5), T(2, 5)], OKEY), null);
  assert.ok(analyzeMeld([T(0, 5), JOKER()], OKEY));
});

test('cozucu: 101 uzeri acilis bulur', () => {
  const hand = [
    T(0, 11), T(0, 12), T(0, 13), // 36
    T(1, 13), T(2, 13), T(3, 13), // 39
    T(2, 9), T(2, 10), T(2, 8), // 27
    T(3, 2), T(1, 1), T(0, 6), T(2, 4), T(3, 7),
  ];
  const sol = solveMelds(hand, OKEY);
  assert.ok(sol.value >= 101, `deger ${sol.value}`);
  assert.ok(canOpen(hand, OKEY));
  const ids = sol.melds.flat();
  assert.strictEqual(new Set(ids).size, ids.length, 'ayrik olmali');
});

test('cozucu: acilamayan el', () => {
  const hand = [T(0, 1), T(1, 3), T(2, 5), T(3, 7), T(0, 9), T(1, 11), T(2, 13), T(3, 2), T(0, 4), T(1, 6), T(2, 8), T(3, 10), T(0, 12), T(1, 1)];
  assert.ok(!canOpen(hand, OKEY));
});

test('cift acilis: 5 cift', () => {
  const hand = [T(0, 1), T(0, 1), T(1, 3), T(1, 3), T(2, 5), T(2, 5), T(3, 7), T(3, 7), T(0, 9), JOKER(), T(1, 11), T(2, 13), T(3, 2), T(0, 4)];
  assert.ok(maxPairs(hand, OKEY) >= 5);
  assert.ok(canOpen(hand, OKEY));
});

test('deste 106 tas, 2 sahte okey', () => {
  const d = buildDeck();
  assert.strictEqual(d.length, 106);
  assert.strictEqual(d.filter((t) => t.fake).length, 2);
});

test('oyun: dagitim, sira, cekme/atma kurallari', () => {
  const g = new OkeyGame({ rounds: 1, rng: () => 0.42 });
  const s = g.starter;
  assert.strictEqual(g.players[s].hand.length, 15);
  assert.strictEqual(g.players[(s + 1) % 4].hand.length, 14);
  assert.strictEqual(g.deck.length, 106 - 1 - 57);
  // sira baskasinda
  assert.strictEqual(g.draw((s + 1) % 4, 'deck').ok, false);
  // baslayan cekmeden atar
  const t = g.players[s].hand[0];
  assert.strictEqual(g.discard(s, t.id).ok, true);
  assert.strictEqual(g.current, (s + 1) % 4);
  // cekmeden atamaz
  assert.strictEqual(g.discard(g.current, g.players[g.current].hand[0].id).ok, false);
  assert.strictEqual(g.draw(g.current, 'deck').ok, true);
});

test('oyun: el acamayacaksan yerden tas alinamaz', () => {
  const g = new OkeyGame({ rounds: 1, rng: () => 0.1 });
  const s = g.starter;
  g.discard(s, g.players[s].hand[0].id);
  const nxt = g.current;
  g.players[nxt].hand = [T(0, 1), T(1, 3), T(2, 5), T(3, 7), T(0, 9), T(1, 11), T(2, 13), T(3, 2), T(0, 4), T(1, 6), T(2, 8), T(3, 10), T(0, 12), T(1, 1)];
  const r = g.draw(nxt, 'discard');
  assert.strictEqual(r.ok, false);
});

test('oyun: puanlama - kazanan -101, acmayan 202', () => {
  const g = new OkeyGame({ rounds: 1, rng: () => 0.3 });
  const s = g.starter;
  const others = [0, 1, 2, 3].filter((i) => i !== s);
  g.players[s].hand = [g.players[s].hand[0]];
  g.players[s].opened = true;
  g.players[s].mode = 'melds';
  const tile = g.players[s].hand[0];
  g.discard(s, tile.id);
  assert.ok(g.roundOver && g.gameOver);
  assert.strictEqual(g.players[s].roundScore, -101);
  for (const o of others) assert.strictEqual(g.players[o].roundScore, 202);
  assert.strictEqual(g.ranking[0], s);
});

test('50 bot oyunu hatasiz biter', () => {
  require('./okey_sim.js');
});
