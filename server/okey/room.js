/**
 * 101 Okey odasi: 4 koltuk (insan veya bot), zamanlayicilar, ekonomi.
 *
 * Ekonomi (sehirli odada): her INSAN oyuncu giris ucretini (F) oyun basinda
 * oder. Bot koltuklari ucret odemez. Oyun sonunda siralama (en dusuk toplam
 * puan en iyi): 1. -> 2.4F, 2. -> 1F (iade), digerleri 0. Sadece sehir
 * kuyrugu (mode==='city') maclarinda 1. XP + sehir parcasi, 2.-4. kademeli
 * XP kazanir. Oyundan kalkan insan ucretini kaybeder ve odul alamaz; yerine
 * bot oynamaya devam eder.
 */
const { OkeyGame } = require('./game');
const { nextAction } = require('./bot');
const { solveMelds, analyzeMeld } = require('./melds');
const { chargeEntryFeeMany, payReward } = require('../game/wallet');
const { awardXp } = require('../game/leveling');
const { awardFragment } = require('../game/workshop');
const { consumePower } = require('../game/powerups');

const TURN_SECONDS = 45;
const ROUND_BREAK_SECONDS = process.env.OKEY_FAST === '1' ? 0.01 : 8;
const FAST = process.env.OKEY_FAST === '1'; // testler icin gecikmesiz
const BOT_DELAY_MIN = FAST ? 0 : 900;
const BOT_DELAY_MAX = FAST ? 1 : 1700;
const AFK_LIMIT = 2;
const RECONNECT_GRACE_MS = process.env.OKEY_FAST === '1' ? 200 : 120000;
const ROUNDS = 3;
const PRIZE_MULT = [2.4, 1, 0, 0];
const XP_MULT = [1, 0.5, 0.25, 0.1];
const BOT_NAMES = ['Ayşe', 'Mehmet', 'Zeynep', 'Can', 'Elif', 'Burak', 'Selin', 'Emre'];

class OkeyRoom {
  constructor({ id, mode, io, city = null, onFinished }) {
    this.id = id;
    this.mode = mode; // 'private' | 'city'
    this.io = io;
    this.city = city; // { id, name, entryFee } | null
    this.onFinished = onFinished;

    this.seats = []; // { type, socketId, uid, name, connected, left, afk }
    this.status = 'waiting'; // 'waiting' | 'active' | 'over'
    this.game = null;
    this.deadline = null;

    this._turnTimer = null;
    this._botTimer = null;
    this._roundTimer = null;
    this._settled = false;
  }

  get entryFee() { return this.city ? this.city.entryFee : 0; }
  get isFull() { return this.seats.filter((s) => s.type === 'human').length >= 4; }

  /** roomManager uyumlulugu: bekleme odasindaki insan oyuncular. */
  get players() { return this.seats.filter((s) => s.type === 'human'); }

  addPlayer(socketId, name, uid = null) {
    const seat = {
      type: 'human', socketId, uid,
      name: (name || 'Oyuncu').toString().slice(0, 20),
      connected: true, left: false, afk: 0,
    };
    this.seats.push(seat);
    this._emitPlayers();
    return this.seats.length - 1;
  }

  indexOfSocket(socketId) { return this.seats.findIndex((s) => s.socketId === socketId); }
  humanSeats() { return this.seats.filter((s) => s.type === 'human'); }

  _emitTo(seat, event, payload) {
    if (seat && seat.type === 'human' && seat.connected && seat.socketId) {
      this.io.to(seat.socketId).emit(event, payload);
    }
  }

  _emitPlayers() {
    if (this.status !== 'waiting') return;
    const list = this.humanSeats().map((s) => ({ name: s.name }));
    for (const s of this.humanSeats()) this._emitTo(s, 'room_players', { players: list, hostIndex: 0, code: this.id });
  }

  // ---------------------------------------------------------------- baslatma
  async start() {
    if (this.status !== 'waiting') return;
    const humans = this.humanSeats();
    if (humans.length === 0) return;
    this.status = 'starting';

    if (this.city) {
      if (humans.some((h) => !h.uid)) {
        for (const h of humans) this._emitTo(h, 'room_error', { message: 'Kimlik doğrulanamadı. Çıkış yapıp tekrar giriş yapın.' });
        this.status = 'over';
        this._finish();
        return;
      }
      let result;
      try {
        result = await chargeEntryFeeMany(humans.map((h) => h.uid), this.entryFee);
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error(`[wallet] charge failed room ${this.id}:`, err);
        for (const h of humans) this._emitTo(h, 'room_error', { message: 'Bir hata oluştu, oyun başlatılamadı.' });
        this.status = 'over';
        this._finish();
        return;
      }
      if (!result.ok) {
        for (const h of humans) {
          const lacking = result.insufficientUids.includes(h.uid);
          this._emitTo(h, 'room_error', {
            message: lacking ? "Bu şehre girmek için yeterli RC'niz yok." : "Bir oyuncunun yeterli RC'si olmadığı için oyun iptal edildi.",
          });
        }
        this.status = 'over';
        this._finish();
        return;
      }
    }

    // Bos koltuklari botlarla doldur, koltuk sirasini karistir.
    const names = BOT_NAMES.slice().sort(() => Math.random() - 0.5);
    while (this.seats.length < 4) {
      this.seats.push({ type: 'bot', name: `${names.pop()} (Bot)`, connected: false, left: false, afk: 0 });
    }
    this.seats = this.seats.slice().sort(() => Math.random() - 0.5);

    this.status = 'active';
    this.game = new OkeyGame({ playerCount: 4, rounds: ROUNDS });
    const names4 = this.seats.map((s) => s.name);
    this.seats.forEach((seat, i) => {
      this._emitTo(seat, 'match_found', {
        roomId: this.id, mySeat: i, names: names4, city: this.city, rounds: ROUNDS,
        humans: this.seats.map((s) => s.type === 'human'),
      });
    });
    this._broadcast();
    this._scheduleTurn();
  }

  // --------------------------------------------------------------- yayin
  _names() { return this.seats.map((s) => s.name); }

  _broadcast() {
    if (!this.game) return;
    const names = this._names();
    this.seats.forEach((seat, i) => {
      this._emitTo(seat, 'okey_state', {
        view: this.game.viewFor(i, names),
        deadline: this.deadline,
        humans: this.seats.map((s) => s.type === 'human' && !s.left),
      });
    });
  }

  // ------------------------------------------------------------ tur yonetimi
  _clearTimers() {
    clearTimeout(this._turnTimer);
    clearTimeout(this._botTimer);
    clearTimeout(this._roundTimer);
    this._turnTimer = this._botTimer = this._roundTimer = null;
  }

  _isAuto(seat) {
    return seat.type === 'bot' || seat.left || !seat.connected || seat.afk >= AFK_LIMIT;
  }

  _scheduleTurn() {
    clearTimeout(this._turnTimer);
    clearTimeout(this._botTimer);
    if (this.status !== 'active') return;
    const game = this.game;

    if (game.gameOver) {
      this.deadline = null;
      this._broadcast();
      this._settle();
      return;
    }
    if (game.roundOver) {
      this.deadline = Date.now() + ROUND_BREAK_SECONDS * 1000;
      this._broadcast();
      this._roundTimer = setTimeout(() => {
        if (this.status !== 'active') return;
        game.nextRound();
        this._broadcast();
        this._scheduleTurn();
      }, ROUND_BREAK_SECONDS * 1000);
      return;
    }

    const seat = this.seats[game.current];
    if (this._isAuto(seat)) {
      this.deadline = null;
      const delay = BOT_DELAY_MIN + Math.random() * (BOT_DELAY_MAX - BOT_DELAY_MIN);
      this._botTimer = setTimeout(() => this._botStep(), delay);
    } else {
      this.deadline = Date.now() + TURN_SECONDS * 1000;
      this._turnTimer = setTimeout(() => this._onTurnTimeout(), TURN_SECONDS * 1000);
    }
    this._broadcast();
  }

  _applyAction(idx, a) {
    const g = this.game;
    switch (a.type) {
      case 'draw': return g.draw(idx, a.source);
      case 'lay': return g.layMelds(idx, a.groups);
      case 'add': {
        // Per jokerliyse ve normal isleme olmuyorsa okey degistirmeyi dene.
        const r = g.addToMeld(idx, a.tileId, a.owner, a.meld);
        if (r.ok) return r;
        const meld = g.players[a.owner] && g.players[a.owner].melds[a.meld];
        if (meld) {
          for (const j of meld.tiles.filter((t) => !t.fake && t.color === g.okey.color && t.number === g.okey.number)) {
            const sr = g.swapJoker(idx, a.tileId, a.owner, a.meld, j.id);
            if (sr.ok) return sr;
          }
        }
        return r;
      }
      case 'swap': return g.swapJoker(idx, a.tileId, a.owner, a.meld, a.jokerId);
      case 'discard': return g.discard(idx, a.tileId);
      default: return { ok: false, error: 'Bilinmeyen hamle.' };
    }
  }

  /** Bir bot/otomatik hamle yapar; tur bitmediyse bir sonraki adimi planlar. */
  _botStep() {
    if (this.status !== 'active') return;
    const g = this.game;
    if (g.roundOver || g.gameOver) return;
    const idx = g.current;
    const a = nextAction(g, idx);
    const before = g.current;
    const beforeRound = g.round;
    let r = this._applyAction(idx, a);
    if (!r.ok) {
      // Guvenli yedek: ceken yoksa ceksin, yoksa en basit atis.
      if (g.phase === 'draw') r = g.draw(idx, 'deck');
      else {
        const hand = g.players[idx].hand;
        r = g.discard(idx, hand[0].id);
        if (!r.ok) r = g.draw(idx, 'deck');
      }
    }
    this._afterMove(before, beforeRound);
  }

  _afterMove(prevCurrent, prevRound) {
    this._broadcast();
    const g = this.game;
    if (g.roundOver || g.gameOver || g.current !== prevCurrent || g.round !== prevRound) {
      this._scheduleTurn();
    } else {
      this._scheduleTurn();
    }
  }

  _onTurnTimeout() {
    if (this.status !== 'active') return;
    const seat = this.seats[this.game.current];
    seat.afk += 1;
    this._botStep();
  }

  // --------------------------------------------------------- insan hamleleri
  handleAction(socketId, action) {
    if (this.status !== 'active') return;
    const idx = this.indexOfSocket(socketId);
    if (idx === -1) return;
    const seat = this.seats[idx];
    const g = this.game;
    const before = g.current;
    const beforeRound = g.round;
    const r = this._applyAction(idx, action);
    if (!r.ok) {
      this._emitTo(seat, 'okey_error', { message: r.error });
      return;
    }
    seat.afk = 0;
    clearTimeout(this._turnTimer);
    this._afterMove(before, beforeRound);
  }

  /** Istemcinin istegi: elini en iyi per dizilimine gore dizme onerisi. */
  arrange(socketId) {
    if (this.status !== 'active') return;
    const idx = this.indexOfSocket(socketId);
    if (idx === -1) return;
    const hand = this.game.players[idx].hand;
    const sol = solveMelds(hand, this.game.okey);
    const inMelds = new Set(sol.melds.flat());
    this._emitTo(this.seats[idx], 'okey_arrange_result', {
      groups: sol.melds,
      rest: hand.filter((t) => !inMelds.has(t.id)).map((t) => t.id),
    });
  }

  /** Raftaki per adaylarinin gecerlilik/puan onizlemesi (tur beklemez). */
  preview(socketId, groups) {
    if (this.status !== 'active' || !Array.isArray(groups)) return;
    const idx = this.indexOfSocket(socketId);
    if (idx === -1) return;
    const hand = this.game.players[idx].hand;
    const types = [];
    const values = groups.slice(0, 20).map((g) => {
      if (!Array.isArray(g)) { types.push(null); return -1; }
      const tiles = g.map((id) => hand.find((t) => t.id === id));
      if (tiles.some((t) => !t)) { types.push(null); return -1; }
      const a = analyzeMeld(tiles, this.game.okey);
      types.push(a ? a.type : null);
      return a ? a.value : -1;
    });
    const total = values.reduce((sum, v, i) => (types[i] && types[i] !== 'pair' ? sum + v : sum), 0);
    const pairs = types.filter((t) => t === 'pair').length;
    this._emitTo(this.seats[idx], 'okey_preview_result', { values, types, total, pairs });
  }

  async usePower(socketId, power) {
    if (this.status !== 'active' || this._powerBusy) return;
    const idx = this.indexOfSocket(socketId);
    if (idx === -1) return;
    const seat = this.seats[idx];
    const g = this.game;
    if (!seat.uid) return;
    if (idx !== g.current) { this._emitTo(seat, 'power_error', { message: 'Güç sadece sıra sendeyken kullanılır.' }); return; }
    if (g.players[idx].powerUsed) { this._emitTo(seat, 'power_error', { message: 'Bu elde zaten bir güç kullandın.' }); return; }
    if (!['kahin', 'kalkan', 'zorba'].includes(power)) return;
    if (power === 'kahin' && g.deck.length === 0) { this._emitTo(seat, 'power_error', { message: 'Destede taş kalmadı.' }); return; }

    this._powerBusy = true;
    try {
      const ok = await consumePower(seat.uid, power);
      if (!ok) { this._emitTo(seat, 'power_error', { message: 'Bu güce sahip değilsin.' }); return; }
      const res = g.usePower(idx, power);
      if (!res.ok) { this._emitTo(seat, 'power_error', { message: res.error }); return; }
      this._emitTo(seat, 'power_used', { power });
      if (power === 'kahin' && res.peek) {
        this._emitTo(seat, 'okey_peek', { tile: { id: res.peek.id, c: res.peek.color, n: res.peek.number, ...(res.peek.fake ? { f: 1 } : {}) } });
      }
      this._broadcast();
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(`[power] failed room ${this.id}:`, err);
    } finally {
      this._powerBusy = false;
    }
  }

  // ------------------------------------------------------------------ bitis
  async _settle() {
    if (this._settled) return;
    this._settled = true;
    this.status = 'over';
    this._clearTimers();
    const g = this.game;
    const payouts = {};
    try {
      if (this.city) {
        const fee = this.entryFee;
        for (let rank = 0; rank < g.ranking.length; rank++) {
          const seatIdx = g.ranking[rank];
          const seat = this.seats[seatIdx];
          if (seat.type !== 'human' || seat.left || !seat.uid) continue;
          const prize = Math.round(fee * PRIZE_MULT[rank]);
          payouts[seatIdx] = prize;
          if (prize > 0) await payReward(seat.uid, prize);
          if (this.mode === 'city') {
            await awardXp(seat.uid, Math.max(1, Math.round((fee / 10) * XP_MULT[rank])));
            if (rank === 0) await awardFragment(seat.uid, this.city.id);
          }
        }
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(`[wallet] settle failed room ${this.id}:`, err);
    }
    const names = this._names();
    this.seats.forEach((seat, i) => {
      this._emitTo(seat, 'okey_over', {
        ranking: g.ranking,
        totals: g.players.map((p) => p.total),
        names,
        payouts,
        youPaid: payouts[i] ?? 0,
      });
    });
    this._broadcast();
  }

  /** Oyuncu ayrildi (voluntary) ya da baglantisi koptu. Aktif oyunda yerine
   * bot oynar; kopan oyuncu RECONNECT_GRACE_MS icinde ayni hesapla
   * dönerse koltugunu geri alir (reattach), donmezse ucreti/odulu kaybeder. */
  handlePlayerGone(socketId, { voluntary = true } = {}) {
    const idx = this.indexOfSocket(socketId);
    if (idx === -1) return;
    const seat = this.seats[idx];

    if (this.status === 'waiting' || this.status === 'starting') {
      this.seats.splice(idx, 1);
      if (idx === 0 || this.seats.length === 0) {
        for (const s of this.humanSeats()) this._emitTo(s, 'room_error', { message: 'Oda sahibi odadan ayrıldı.' });
        this.status = 'over';
        this._finish();
        return;
      }
      this._emitPlayers();
      return;
    }

    seat.connected = false;
    if (voluntary || this.status === 'over') {
      seat.left = true;
    } else {
      clearTimeout(seat.dropTimer);
      seat.dropTimer = setTimeout(() => {
        seat.left = true;
        this._checkEmpty();
      }, RECONNECT_GRACE_MS);
    }
    if (this.status === 'active' && this.game.current === idx && !this.game.roundOver) {
      clearTimeout(this._turnTimer);
      this._scheduleTurn();
    }
    this._checkEmpty();
  }

  _checkEmpty() {
    if (this.status === 'over' && this._finished) return;
    const anyoneHere = this.humanSeats().some((s) => !s.left);
    if (!anyoneHere) {
      this.status = 'over';
      this._finish();
    }
  }

  /** Kopan oyuncu ayni uid ile yeniden baglandi: koltugunu geri ver. */
  reattach(socketId, uid) {
    const seat = this.seats.find((s) => s.type === 'human' && s.uid && s.uid === uid && !s.left);
    if (!seat || seat.connected) return false;
    clearTimeout(seat.dropTimer);
    seat.socketId = socketId;
    seat.connected = true;
    seat.afk = 0;
    const idx = this.seats.indexOf(seat);
    if (this.status === 'active' || this.status === 'over') {
      this._emitTo(seat, 'match_found', {
        roomId: this.id, mySeat: idx, names: this._names(), city: this.city, rounds: ROUNDS,
        humans: this.seats.map((s) => s.type === 'human'),
      });
      this._broadcast();
      if (this.status === 'active') this._scheduleTurn();
    }
    return true;
  }

  _finish() {
    this._finished = true;
    for (const seat of this.seats) clearTimeout(seat.dropTimer);
    this._clearTimers();
    if (this.onFinished) this.onFinished(this.id);
  }

  destroy() { this._clearTimers(); }
}

module.exports = OkeyRoom;
