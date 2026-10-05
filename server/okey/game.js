/**
 * 101 Okey oyun motoru (saf mantik: soket/zamanlayici yok). 4 oyuncu,
 * N el. Tum kurallarin tek dogru kaynagi burasidir; istemci sadece gosterir.
 *
 * Sira: oyuncular 0..3 koltuk sirasiyla oynar. Bir oyuncu "onceki" oyuncunun
 * (idx+3)%4 attigi son tasi alabilir.
 */
const { buildDeck, shuffle, okeyFaceFor, isJoker, faceOf } = require('./tiles');
const { analyzeMeld, canOpen, OPEN_THRESHOLD, MIN_PAIRS_TO_OPEN } = require('./melds');

const HAND_SIZE = 14;
const UNOPENED_PENALTY = 202;
const WIN_BONUS = -101;
const JOKER_LEFTOVER_VALUE = 25;

function tileJson(t, okey) {
  const o = { id: t.id, c: t.color, n: t.number };
  if (t.fake) o.f = 1;
  if (okey && isJoker(t, okey)) o.j = 1;
  return o;
}

class OkeyGame {
  constructor({ playerCount = 4, rounds = 3, rng = Math.random } = {}) {
    this.playerCount = playerCount;
    this.rounds = rounds;
    this.rng = rng;
    this.round = 0;
    this.starter = Math.floor(rng() * playerCount);
    this.players = Array.from({ length: playerCount }, () => ({
      hand: [], melds: [], opened: false, mode: null, discards: [],
      total: 0, roundScore: 0, powerUsed: null, shield: false,
    }));
    this.gameOver = false;
    this.roundOver = false;
    this.roundResult = null;
    this.ranking = null;
    this.startRound();
  }

  // ------------------------------------------------------------------ kurulum
  startRound() {
    this.round += 1;
    if (this.round > 1) this.starter = (this.starter + 1) % this.playerCount;
    this.roundOver = false;
    this.roundResult = null;

    const deck = shuffle(buildDeck(), this.rng);
    let indicator;
    for (;;) {
      indicator = deck.pop();
      if (!indicator.fake) break;
      deck.splice(Math.floor(this.rng() * (deck.length + 1)), 0, indicator);
    }
    this.indicator = indicator;
    this.okey = okeyFaceFor(indicator);

    for (const p of this.players) {
      p.hand = []; p.melds = []; p.opened = false; p.mode = null;
      p.discards = []; p.roundScore = 0; p.powerUsed = null; p.shield = false;
    }
    for (let i = 0; i < this.playerCount; i++) {
      const count = i === this.starter ? HAND_SIZE + 1 : HAND_SIZE;
      for (let k = 0; k < count; k++) this.players[i].hand.push(deck.pop());
    }
    this.deck = deck;
    this.current = this.starter;
    this.phase = 'play'; // baslayan oyuncu 15 tasla cekmeden oynar
    this.mustOpenTileId = null;
    this.skipTarget = null;
    this.lastEvent = { type: 'deal' };
  }

  tileById(player, id) {
    return player.hand.find((t) => t.id === id) || null;
  }

  _err(error) { return { ok: false, error }; }

  _turnCheck(idx, phase) {
    if (this.gameOver || this.roundOver) return 'Oyun/el bitti.';
    if (idx !== this.current) return 'Sıra sende değil.';
    if (phase && this.phase !== phase) {
      return phase === 'draw' ? 'Önce taş çekmelisin.' : 'Önce taş çekmelisin / bu işlemi şimdi yapamazsın.';
    }
    return null;
  }

  // -------------------------------------------------------------------- hamleler
  draw(idx, source) {
    const e = this._turnCheck(idx, 'draw');
    if (e) return this._err(e);
    const player = this.players[idx];

    if (source === 'discard') {
      const prev = this.players[(idx + this.playerCount - 1) % this.playerCount];
      const top = prev.discards[prev.discards.length - 1];
      if (!top) return this._err('Alınacak taş yok.');
      if (!player.opened && !canOpen([...player.hand, top], this.okey)) {
        return this._err('Bu taşı alırsan elini açamazsın. Açamayacaksan sadece desteden çekebilirsin.');
      }
      prev.discards.pop();
      player.hand.push(top);
      this.mustOpenTileId = player.opened ? null : top.id;
      this.phase = 'play';
      this.lastEvent = { type: 'draw', player: idx, from: 'discard', tile: tileJson(top, this.okey) };
      return { ok: true, tile: top };
    }

    if (this.deck.length === 0) {
      this._finishRound(null, null);
      return { ok: true, ended: true };
    }
    const tile = this.deck.pop();
    player.hand.push(tile);
    this.mustOpenTileId = null;
    this.phase = 'play';
    this.lastEvent = { type: 'draw', player: idx, from: 'deck' };
    return { ok: true, tile };
  }

  /** Eli ac / yeni per indir. groups: tas id dizilerinin dizisi. */
  layMelds(idx, groups) {
    const e = this._turnCheck(idx, 'play');
    if (e) return this._err(e);
    const player = this.players[idx];
    if (!Array.isArray(groups) || groups.length === 0) return this._err('İndirilecek per yok.');

    const seen = new Set();
    const analyses = [];
    for (const g of groups) {
      if (!Array.isArray(g)) return this._err('Geçersiz per.');
      const tiles = [];
      for (const id of g) {
        if (seen.has(id)) return this._err('Aynı taş iki kez kullanılamaz.');
        seen.add(id);
        const t = this.tileById(player, id);
        if (!t) return this._err('Bu taş elinde yok.');
        tiles.push(t);
      }
      const analysis = analyzeMeld(tiles, this.okey);
      if (!analysis) return this._err('Geçersiz per dizilimi.');
      analyses.push({ tiles, analysis });
    }

    const pairCount = analyses.filter((a) => a.analysis.type === 'pair').length;
    if (pairCount > 0 && pairCount !== analyses.length) {
      return this._err('Çift ve per aynı anda açılamaz.');
    }
    const newMode = pairCount > 0 ? 'pairs' : 'melds';

    if (player.opened) {
      if (player.mode !== newMode) {
        return this._err(player.mode === 'pairs' ? 'Çift açtığın için sadece çift indirebilirsin.' : 'Per açtığın için çift indiremezsin.');
      }
    } else if (newMode === 'pairs') {
      if (analyses.length < MIN_PAIRS_TO_OPEN) return this._err(`Çift açmak için en az ${MIN_PAIRS_TO_OPEN} çift gerekir.`);
    } else {
      const total = analyses.reduce((s, a) => s + a.analysis.value, 0);
      if (total < OPEN_THRESHOLD) return this._err(`El açmak için en az ${OPEN_THRESHOLD} puan gerekir (şu an ${total}).`);
    }

    if (this.mustOpenTileId != null && !player.opened && !seen.has(this.mustOpenTileId)) {
      return this._err('Yerden aldığın taşı kullanarak el açmalısın.');
    }

    for (const a of analyses) {
      player.hand = player.hand.filter((t) => !a.tiles.includes(t));
      player.melds.push({ type: a.analysis.type, tiles: a.tiles, analysis: a.analysis });
    }
    player.opened = true;
    player.mode = newMode;
    this.mustOpenTileId = null;
    this.lastEvent = { type: 'lay', player: idx, count: analyses.length };

    if (player.hand.length === 0) this._finishRound(idx, null);
    return { ok: true };
  }

  /** Acilmis bir pere tas isle. */
  addToMeld(idx, tileId, ownerIdx, meldIdx) {
    const e = this._turnCheck(idx, 'play');
    if (e) return this._err(e);
    const player = this.players[idx];
    if (!player.opened) return this._err('Önce elini açmalısın.');
    if (player.mode !== 'melds') return this._err('Çift açtığın için tas işleyemezsin.');
    const tile = this.tileById(player, tileId);
    if (!tile) return this._err('Bu taş elinde yok.');
    const meld = this.players[ownerIdx]?.melds[meldIdx];
    if (!meld || meld.type === 'pair') return this._err('Bu pere taş işlenemez.');

    const analysis = analyzeMeld([...meld.tiles, tile], this.okey);
    if (!analysis || analysis.type !== meld.type) return this._err('Bu taş bu pere işlenemez.');

    meld.tiles.push(tile);
    meld.analysis = analysis;
    player.hand = player.hand.filter((t) => t !== tile);
    this.lastEvent = { type: 'add', player: idx, owner: ownerIdx, meld: meldIdx };
    if (player.hand.length === 0) this._finishRound(idx, null);
    return { ok: true };
  }

  /** Tablodaki bir perdeki jokerin yerine gercek tasi koyup jokeri al. */
  swapJoker(idx, tileId, ownerIdx, meldIdx, jokerId) {
    const e = this._turnCheck(idx, 'play');
    if (e) return this._err(e);
    const player = this.players[idx];
    if (!player.opened || player.mode !== 'melds') return this._err('Önce per açmalısın.');
    const tile = this.tileById(player, tileId);
    if (!tile) return this._err('Bu taş elinde yok.');
    if (isJoker(tile, this.okey)) return this._err('Okey ile okey değiştirilemez.');
    const meld = this.players[ownerIdx]?.melds[meldIdx];
    if (!meld || meld.type === 'pair') return this._err('Bu perde joker değiştirilemez.');
    const joker = meld.tiles.find((t) => t.id === jokerId && isJoker(t, this.okey));
    if (!joker) return this._err('Bu perde böyle bir okey yok.');

    const newTiles = meld.tiles.filter((t) => t !== joker).concat(tile);
    const analysis = analyzeMeld(newTiles, this.okey);
    if (!analysis || analysis.type !== meld.type) return this._err('Bu taş okeyin yerine geçemez.');

    meld.tiles = newTiles;
    meld.analysis = analysis;
    player.hand = player.hand.filter((t) => t !== tile);
    player.hand.push(joker);
    this.lastEvent = { type: 'swap', player: idx, owner: ownerIdx, meld: meldIdx };
    return { ok: true };
  }

  discard(idx, tileId) {
    const e = this._turnCheck(idx, 'play');
    if (e) return this._err(e);
    const player = this.players[idx];
    if (this.mustOpenTileId != null && !player.opened) {
      return this._err('Yerden taş aldın: önce elini açmalısın.');
    }
    const tile = this.tileById(player, tileId);
    if (!tile) return this._err('Bu taş elinde yok.');

    player.hand = player.hand.filter((t) => t !== tile);
    player.discards.push(tile);
    this.lastEvent = { type: 'discard', player: idx, tile: tileJson(tile, this.okey) };

    if (player.hand.length === 0) {
      this._finishRound(idx, tile);
      return { ok: true, finished: true };
    }
    this._advanceTurn();
    return { ok: true };
  }

  _advanceTurn() {
    let next = (this.current + 1) % this.playerCount;
    if (this.skipTarget === next) {
      this.skipTarget = null;
      this.lastEvent = { ...this.lastEvent, skipped: next };
      next = (next + 1) % this.playerCount;
    }
    this.current = next;
    this.phase = 'draw';
    this.mustOpenTileId = null;
  }

  // -------------------------------------------------------------------- guclar
  /** kahin: destenin ustundeki tasi gor, kalkan: bu el cezani yariya indir,
   * zorba: siradaki oyuncunun turunu atlat. Her el en fazla 1 guc. */
  usePower(idx, power) {
    const e = this._turnCheck(idx, null);
    if (e) return this._err(e);
    const player = this.players[idx];
    if (player.powerUsed) return this._err('Bu elde zaten bir güç kullandın.');
    if (!['kahin', 'kalkan', 'zorba'].includes(power)) return this._err('Geçersiz güç.');
    const out = { ok: true, power };
    if (power === 'kahin') {
      if (this.deck.length === 0) return this._err('Destede taş kalmadı.');
      out.peek = this.deck[this.deck.length - 1];
    } else if (power === 'kalkan') {
      player.shield = true;
    } else {
      this.skipTarget = (idx + 1) % this.playerCount;
    }
    player.powerUsed = power;
    return out;
  }

  // -------------------------------------------------------------------- bitis
  _leftoverValue(player) {
    let sum = 0;
    for (const t of player.hand) {
      if (isJoker(t, this.okey)) sum += JOKER_LEFTOVER_VALUE;
      else sum += (faceOf(t, this.okey) || { number: 0 }).number;
    }
    return sum;
  }

  _finishRound(winner, lastTile) {
    this.roundOver = true;
    let mult = 1;
    let okeyFinish = false;
    if (winner != null) {
      if (this.players[winner].mode === 'pairs') mult *= 2;
      if (lastTile && isJoker(lastTile, this.okey)) { mult *= 2; okeyFinish = true; }
    }
    const scores = [];
    for (let i = 0; i < this.playerCount; i++) {
      const p = this.players[i];
      let s;
      if (i === winner) {
        s = WIN_BONUS * (okeyFinish ? 2 : 1);
      } else {
        s = p.opened ? this._leftoverValue(p) : UNOPENED_PENALTY;
        s *= mult;
        if (p.shield) s = Math.ceil(s / 2);
      }
      p.roundScore = s;
      p.total += s;
      scores.push(s);
    }
    this.roundResult = { winner, okeyFinish, multiplier: mult, scores };
    this.lastEvent = { type: 'roundEnd', winner };

    if (this.round >= this.rounds) {
      this.gameOver = true;
      const order = this.players.map((p, i) => ({ i, total: p.total, last: p.roundScore }));
      order.sort((a, b) => a.total - b.total || a.last - b.last || a.i - b.i);
      this.ranking = order.map((o) => o.i);
    }
  }

  nextRound() {
    if (this.gameOver || !this.roundOver) return false;
    this.startRound();
    return true;
  }

  // ---------------------------------------------------------------- gorunum
  viewFor(idx, names = []) {
    const okey = this.okey;
    const me = this.players[idx];
    return {
      round: this.round,
      rounds: this.rounds,
      current: this.current,
      phase: this.phase,
      myIndex: idx,
      deckCount: this.deck.length,
      indicator: tileJson(this.indicator),
      okey: { c: okey.color, n: okey.number },
      hand: me ? me.hand.map((t) => tileJson(t, okey)) : [],
      mustOpenTileId: idx === this.current ? this.mustOpenTileId : null,
      roundOver: this.roundOver,
      roundResult: this.roundResult,
      gameOver: this.gameOver,
      ranking: this.ranking,
      lastEvent: this.lastEvent,
      players: this.players.map((p, i) => ({
        seat: i,
        name: names[i] || `Oyuncu ${i + 1}`,
        handCount: p.hand.length,
        opened: p.opened,
        mode: p.mode,
        total: p.total,
        roundScore: p.roundScore,
        powerUsed: p.powerUsed,
        discardTop: p.discards.length ? tileJson(p.discards[p.discards.length - 1], okey) : null,
        discardCount: p.discards.length,
        melds: p.melds.map((m) => ({
          type: m.type,
          tiles: m.analysis.ordered.map((o) => {
            const t = m.tiles.find((x) => x.id === o.id);
            return { ...tileJson(t, okey), as: { c: o.color, n: o.number } };
          }),
        })),
      })),
    };
  }
}

module.exports = { OkeyGame, tileJson, HAND_SIZE, UNOPENED_PENALTY };
