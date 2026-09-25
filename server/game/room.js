const { randomCard } = require('./cards');
const { calculateRound } = require('./scoring');
const { chargeEntryFee, payReward, refundEntryFee } = require('./wallet');
const { awardXp } = require('./leveling');
const { awardFragment } = require('./workshop');
const { consumePower } = require('./powerups');
const {
  WIN_SCORE_THRESHOLD,
  LOSE_SCORE_THRESHOLD,
  MAX_CONSECUTIVE_PASSES,
  DECISION_SECONDS,
  RESULT_DISPLAY_SECONDS,
} = require('./constants');

const VALID_CHOICES = new Set(['risk', 'doubleRisk', 'pass']);
const REMATCH_GRACE_SECONDS = 90;

/**
 * Tek bir esleşmenin (2 oyuncu) tum state machine'ini ve zamanlayicilarini
 * yonetir. lib/state/game/game_notifier.dart + game_state.dart'in iki
 * gercek insan oyuncu icin sunucu tarafi karsiligidir.
 *
 * Sira/oncelik kurali (kaynak tek-oyunculu oyundan birebir tasindi):
 * her elde bir oyuncu "oncelikli"dir ve once o karar verir; karari
 * (karti degil, sadece riske-gir/pas rengi) hemen rakibe acilir, rakip
 * bu bilgiyi gorerek kendi karari verir. Oncelik her elde rakibe gecer.
 *
 * Sehir/giris ucreti: `city` verilmisse (sehir bazli eslesme veya
 * arkadasla oyna), start() cagrildiginda iki oyuncunun da bakiyesi
 * (Firestore, firebase-admin ile yetkili sekilde) kontrol edilip
 * dusulur; oyun sonunda kazanana havuzun tamami (entryFee * 2) odenir,
 * beraberlikte veya bir oyuncu ayrilirsa giris ucreti sahibine iade
 * edilir/rakibe odul olarak verilir (bkz. _settleWallets).
 */
class Room {
  constructor({ id, mode, io, city = null, onFinished }) {
    this.id = id;
    this.mode = mode; // 'private' | 'city' | 'quick'
    this.io = io;
    this.city = city; // { id, name, entryFee } | null
    this.onFinished = onFinished; // (roomId) => void, manager temizligi icin

    this.players = []; // [{ socketId, uid, name, score, consecutivePasses, connected }]
    this.status = 'waiting'; // 'waiting' | 'active' | 'over'
    this.roundId = 0;
    this.cards = [null, null];
    this.choices = [null, null];
    this.tieBreakRound = false;

    this.priorityIndex = null; // bu el kimin once sececegi (0|1)
    this.turnPhase = null; // 'priority' | 'reactive'

    this.rematchRequestedBy = null; // 0|1|null
    this._walletSettled = false; // giris ucreti odendi mi (cift odul/iade onlemi)

    // Bu elde her oyuncunun kullandigi guc (varsa): 'zorba'|'kalkan'|'kahin'|null.
    // Her elde sifirlanir (bkz. _dealNewRound); bir oyuncu elde en fazla
    // 1 guc kullanabilir (bkz. usePower).
    this.activePower = [null, null];

    this._timeoutHandle = null;
    this._nextRoundHandle = null;
    this._gameOverHandle = null;
    this._rematchGraceHandle = null;
  }

  get isFull() {
    return this.players.length >= 2;
  }

  get entryFee() {
    return this.city ? this.city.entryFee : 0;
  }

  addPlayer(socketId, name, uid = null) {
    const index = this.players.length;
    this.players.push({
      socketId,
      uid,
      name: (name || 'Oyuncu').toString().slice(0, 20),
      score: 0,
      consecutivePasses: 0,
      connected: true,
    });
    return index;
  }

  indexOfSocket(socketId) {
    return this.players.findIndex((p) => p.socketId === socketId);
  }

  _emitTo(index, event, payload) {
    const player = this.players[index];
    if (!player) return;
    this.io.to(player.socketId).emit(event, payload);
  }

  /// Iki oyuncu da odaya katilinca cagrilir. Sehirli bir maçsa once giris
  /// ucretini dusmeye calisir; biri karsilayamiyorsa maç hic baslamadan
  /// iptal edilir. Basariliysa esleşme bilgisini gonderip ilk eli dagitir.
  async start() {
    if (this.city) {
      const [a, b] = this.players;
      if (!a.uid || !b.uid) {
        // Kimligi dogrulanmamis bir oyuncu (bkz. server.js auth middleware)
        // sehirli bir maca giremez.
        this._emitTo(0, 'room_error', { message: 'Kimlik doğrulanamadı.' });
        this._emitTo(1, 'room_error', { message: 'Kimlik doğrulanamadı.' });
        this.status = 'over';
        this._finish();
        return;
      }

      let result;
      try {
        result = await chargeEntryFee(a.uid, b.uid, this.entryFee);
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error(`[wallet] chargeEntryFee failed for room ${this.id}:`, err);
        this._emitTo(0, 'room_error', { message: 'Bir hata oluştu, maç başlatılamadı.' });
        this._emitTo(1, 'room_error', { message: 'Bir hata oluştu, maç başlatılamadı.' });
        this.status = 'over';
        this._finish();
        return;
      }
      if (!result.ok) {
        for (let i = 0; i < 2; i++) {
          const isInsufficient = result.insufficientUids.includes(this.players[i].uid);
          this._emitTo(i, 'room_error', {
            message: isInsufficient
              ? 'Bu şehre girmek için yeterli RC\'niz yok.'
              : 'Rakibinizin yeterli RC\'si olmadığı için maç iptal edildi.',
          });
        }
        this.status = 'over';
        this._finish();
        return;
      }
    }

    this.status = 'active';
    // Ilk elde kim once sececek rastgele belirlenir; sonraki her elde
    // rakibe gecer (bkz. _dealNewRound).
    this.priorityIndex = Math.round(Math.random());
    for (let i = 0; i < 2; i++) {
      const opponent = this.players[1 - i];
      this._emitTo(i, 'match_found', {
        roomId: this.id,
        myIndex: i,
        opponentName: opponent.name,
        city: this.city,
      });
    }
    this._dealNewRound();
  }

  _dealNewRound() {
    if (this.status !== 'active') return;

    if (this.roundId > 0) {
      // Ilk el disinda oncelik her zaman bir onceki elin oncelikli
      // oyuncusundan rakibe gecer.
      this.priorityIndex = 1 - this.priorityIndex;
    }

    this.roundId += 1;
    this.cards = [randomCard(), randomCard()];
    this.choices = [null, null];
    this.turnPhase = 'priority';
    this.activePower = [null, null];

    this._clearRoundTimer();
    this._timeoutHandle = setTimeout(() => this._onPriorityTimeout(), DECISION_SECONDS * 1000);

    for (let i = 0; i < 2; i++) {
      this._emitTo(i, 'round_start', {
        roundId: this.roundId,
        yourCard: this.cards[i],
        isYourTurn: i === this.priorityIndex,
      });
    }
  }

  submitChoice(socketId, choice) {
    if (this.status !== 'active') return;
    const index = this.indexOfSocket(socketId);
    if (index === -1) return;
    if (this.choices[index] !== null) return; // zaten secim yapmis

    // Sira kuralinin sunucu tarafi zorunlu kilinmasi: oncelik asamasinda
    // sadece priorityIndex, tepki asamasinda sadece diger oyuncu
    // secim yapabilir.
    const isPriorityTurn = this.turnPhase === 'priority' && index === this.priorityIndex;
    const isReactiveTurn = this.turnPhase === 'reactive' && index !== this.priorityIndex;
    if (!isPriorityTurn && !isReactiveTurn) return;

    if (!VALID_CHOICES.has(choice)) return;

    const player = this.players[index];
    if (choice === 'pass' && player.consecutivePasses >= MAX_CONSECUTIVE_PASSES) {
      return; // gecersiz istek (istemci normalde bu butonu zaten kapatir)
    }
    // ZORBA: rakip bu gucu kullandiysa bu el pas gecemem (bkz. usePower).
    if (choice === 'pass' && this.activePower[1 - index] === 'zorba') {
      return;
    }

    this.choices[index] = choice;

    if (isPriorityTurn) {
      this._advanceToReactivePhase();
    } else {
      this._clearRoundTimer();
      this._resolveRound();
    }
  }

  /// Bir oyuncu oyun ici bir guc kullanmaya calisinca cagrilir. Envanter
  /// dusumu (Firestore, firebase-admin ile) basarili olursa etkiyi bu
  /// elin state'ine isler:
  ///  - ZORBA: rakibin bu el pas gecmesini engeller (bkz. submitChoice).
  ///  - KALKAN: bu elin ceza puanini 0'a sabitler (bkz. _resolveRound).
  ///  - KAHIN: rakibin kartini ANINDA kullanan oyuncuya gonderir (client
  ///    1 saniye gosterip gizler); rakibe HANGI gucun kullanildigi
  ///    soylenmez (casusluk gizli kalir).
  /// Bir oyuncu elde en fazla 1 guc kullanabilir.
  async usePower(socketId, powerType) {
    if (this.status !== 'active') return;
    const index = this.indexOfSocket(socketId);
    if (index === -1) return;
    if (this.activePower[index]) return; // bu el zaten bir guc kullanildi
    if (!['zorba', 'kalkan', 'kahin'].includes(powerType)) return;

    const uid = this.players[index].uid;
    if (!uid) return;

    let consumed;
    try {
      consumed = await consumePower(uid, powerType);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(`[power] consume failed for room ${this.id}:`, err);
      return;
    }
    if (!consumed) {
      this._emitTo(index, 'power_error', { message: 'Bu güce sahip değilsin.' });
      return;
    }
    // Baska bir kontrol sirasinda (async bosluk) el degismis olabilir -
    // artik gecerli degilse envanter zaten dusuldu ama etki uygulanmaz.
    if (this.status !== 'active' || this.activePower[index]) return;

    this.activePower[index] = powerType;

    const payload = { power: powerType };
    if (powerType === 'kahin') {
      payload.opponentCard = this.cards[1 - index];
    }
    this._emitTo(index, 'power_used', payload);

    // ZORBA'nin etkisi zaten pas butonunu kapatarak rakibe belli olur,
    // bu yuzden rakibe bilgi veriliyor (UI'da gostermesi icin). KALKAN/
    // KAHIN gizli kalir.
    if (powerType === 'zorba') {
      this._emitTo(1 - index, 'opponent_used_power', { power: 'zorba' });
    }
  }

  _onPriorityTimeout() {
    if (this.choices[this.priorityIndex] === null) {
      this.choices[this.priorityIndex] = 'timeout';
    }
    this._advanceToReactivePhase();
  }

  /// Oncelikli oyuncu secimini (veya suresi dolunca zaman asimini) yapinca
  /// cagrilir: bu secimin RENGI (karti degil) rakibe hemen acilir ve
  /// rakibin kendi 7 saniyelik karar suresi baslar.
  _advanceToReactivePhase() {
    this.turnPhase = 'reactive';
    const reactiveIndex = 1 - this.priorityIndex;

    this._emitTo(reactiveIndex, 'priority_revealed', {
      choice: this.choices[this.priorityIndex],
    });

    this._clearRoundTimer();
    this._timeoutHandle = setTimeout(() => this._onReactiveTimeout(), DECISION_SECONDS * 1000);
  }

  _onReactiveTimeout() {
    const reactiveIndex = 1 - this.priorityIndex;
    if (this.choices[reactiveIndex] === null) {
      this.choices[reactiveIndex] = 'timeout';
    }
    this._resolveRound();
  }

  _resolveRound() {
    this._clearRoundTimer();

    const { deltaA, deltaB } = calculateRound({
      cardA: this.cards[0],
      choiceA: this.choices[0],
      cardB: this.cards[1],
      choiceB: this.choices[1],
    });
    const deltas = [deltaA, deltaB];

    // KALKAN: bu eli kullanan oyuncu icin negatif bir delta'yi (ceza
    // puanini) 0'a sabitler - kazanclari ETKILEMEZ (bkz. kullanici
    // talebi). Sadece kendi delta'sina uygulanir.
    for (let i = 0; i < 2; i++) {
      if (this.activePower[i] === 'kalkan' && deltas[i] < 0) {
        deltas[i] = 0;
      }
    }

    for (let i = 0; i < 2; i++) {
      this.players[i].score += deltas[i];
      this.players[i].consecutivePasses =
        this.choices[i] === 'pass' ? this.players[i].consecutivePasses + 1 : 0;
    }

    for (let i = 0; i < 2; i++) {
      const opp = 1 - i;
      this._emitTo(i, 'round_result', {
        roundId: this.roundId,
        yourCard: this.cards[i],
        opponentCard: this.cards[opp],
        yourChoice: this.choices[i],
        opponentChoice: this.choices[opp],
        yourDelta: deltas[i],
        opponentDelta: deltas[opp],
        yourScore: this.players[i].score,
        opponentScore: this.players[opp].score,
      });
    }

    this._checkGameOver();
  }

  /// lib/state/game/game_notifier.dart _checkGameOver ile birebir ayni mantik.
  _checkGameOver() {
    const p0 = this.players[0];
    const p1 = this.players[1];
    const p0Busted = p0.score <= LOSE_SCORE_THRESHOLD;
    const p1Busted = p1.score <= LOSE_SCORE_THRESHOLD;
    const p0Target = p0.score >= WIN_SCORE_THRESHOLD;
    const p1Target = p1.score >= WIN_SCORE_THRESHOLD;

    let winnerIndex = null;
    let gameOver = false;

    if (this.tieBreakRound) {
      this.tieBreakRound = false;
      if (p0.score !== p1.score) winnerIndex = p0.score > p1.score ? 0 : 1;
      gameOver = true;
    } else if (p0Busted && p1Busted) {
      if (p0.score === p1.score) {
        this.tieBreakRound = true;
      } else {
        winnerIndex = p0.score > p1.score ? 0 : 1;
        gameOver = true;
      }
    } else if (p0Busted) {
      winnerIndex = 1;
      gameOver = true;
    } else if (p1Busted) {
      winnerIndex = 0;
      gameOver = true;
    } else if (p0Target && p1Target) {
      if (p0.score !== p1.score) {
        winnerIndex = p0.score > p1.score ? 0 : 1;
        gameOver = true;
      }
    } else if (p0Target) {
      winnerIndex = 0;
      gameOver = true;
    } else if (p1Target) {
      winnerIndex = 1;
      gameOver = true;
    }

    if (gameOver) {
      // Son elin kartlarini/sonucunu normal el gecisi kadar (3sn)
      // gosterdikten sonra kazanan/kaybeden ekranini aciyoruz; boylece
      // oyuncu son elin kartlarini gormeden aniden sonuc ekranina
      // dusmuyor.
      this._gameOverHandle = setTimeout(() => {
        this.status = 'over';
        // Odul/iade odemesini beklemeden hemen bildiriyoruz: oyuncu
        // sonuc ekranini bir Firestore yazma turu kadar gecikmeden
        // gormeli. _settleWallets kendi hatalarini zaten loglar (bkz.
        // yukarisi), bu yuzden bilerek await'lenmiyor.
        this._settleWallets(winnerIndex);
        for (let i = 0; i < 2; i++) {
          const opp = 1 - i;
          this._emitTo(i, 'game_over', {
            youWon: winnerIndex === null ? null : winnerIndex === i,
            yourScore: this.players[i].score,
            opponentScore: this.players[opp].score,
            reason: 'score',
          });
        }
        this._startRematchGracePeriod();
      }, RESULT_DISPLAY_SECONDS * 1000);
    } else {
      this._nextRoundHandle = setTimeout(() => this._dealNewRound(), RESULT_DISPLAY_SECONDS * 1000);
    }
  }

  /// Sehirli bir mactaysa (this.city != null) kazanana havuzun tamamini
  /// (entryFee * 2) oder; beraberlikte (winnerIndex null) her ikisine de
  /// giris ucretini iade eder. En fazla bir kere calisir (_walletSettled).
  ///
  /// XP ve SEHIR PARCASI SADECE sehir kuyrugu (mode === 'city') maclarinda
  /// kazanana verilir - "Arkadasinla Oyna" ile kurulan bir odada
  /// (mode === 'private', bir sehir secilmis olsa bile) ikisi de
  /// verilmez (kullanicinin acik talebi). XP miktari sehrin giris
  /// ucretinin onda biri (istanbul 250 -> 25xp, maras 250000 -> 25000xp).
  async _settleWallets(winnerIndex) {
    if (!this.city || this._walletSettled) return;
    this._walletSettled = true;

    try {
      if (winnerIndex === null) {
        await Promise.all(this.players.map((p) => refundEntryFee(p.uid, this.entryFee)));
      } else {
        await payReward(this.players[winnerIndex].uid, this.entryFee * 2);
        if (this.mode === 'city') {
          const xpGained = Math.max(1, Math.round(this.entryFee / 10));
          await awardXp(this.players[winnerIndex].uid, xpGained);
          await awardFragment(this.players[winnerIndex].uid, this.city.id);
        }
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(`[wallet] settle failed for room ${this.id}:`, err);
    }
  }

  /// Oyun bitince odayi hemen yok etmek yerine bir sure daha acik tutar,
  /// boylece oyuncular "Tekrar Meydan Oku" ile ayni odada yeniden
  /// eslesebilir. Sure dolarsa veya biri ayrilirsa oda kapanir.
  _startRematchGracePeriod() {
    this.rematchRequestedBy = null;
    this._rematchGraceHandle = setTimeout(() => this._finish(), REMATCH_GRACE_SECONDS * 1000);
  }

  requestRematch(socketId) {
    if (this.status !== 'over') return;
    const index = this.indexOfSocket(socketId);
    if (index === -1 || this.rematchRequestedBy !== null) return;

    this.rematchRequestedBy = index;
    this._emitTo(index, 'rematch_pending', {});
    this._emitTo(1 - index, 'rematch_requested', {});
  }

  acceptRematch(socketId) {
    if (this.status !== 'over' || this.rematchRequestedBy === null) return;
    const index = this.indexOfSocket(socketId);
    if (index === -1 || index === this.rematchRequestedBy) return; // sadece rakip onaylayabilir

    if (this._rematchGraceHandle) clearTimeout(this._rematchGraceHandle);
    this._rematchGraceHandle = null;
    this.rematchRequestedBy = null;

    // Bir rematch, ilk maçla ayni sehir/giris ucretini kullanir; start()
    // yeni bir tur icin giris ucretini tekrar tahsil eder.
    for (const p of this.players) {
      p.score = 0;
      p.consecutivePasses = 0;
    }
    this.tieBreakRound = false;
    this._walletSettled = false;

    if (this.city) {
      chargeEntryFee(this.players[0].uid, this.players[1].uid, this.entryFee).then((result) => {
        if (!result.ok) {
          for (let i = 0; i < 2; i++) {
            const isInsufficient = result.insufficientUids.includes(this.players[i].uid);
            this._emitTo(i, 'room_error', {
              message: isInsufficient
                ? 'Bu şehre girmek için yeterli RC\'niz yok.'
                : 'Rakibinizin yeterli RC\'si olmadığı için rematch iptal edildi.',
            });
          }
          this.status = 'over';
          this._finish();
          return;
        }
        this.status = 'active';
        for (let i = 0; i < 2; i++) this._emitTo(i, 'rematch_accepted', {});
        this._dealNewRound();
      }).catch((err) => {
        // eslint-disable-next-line no-console
        console.error(`[wallet] rematch chargeEntryFee failed for room ${this.id}:`, err);
        this._emitTo(0, 'room_error', { message: 'Bir hata oluştu, rematch başlatılamadı.' });
        this._emitTo(1, 'room_error', { message: 'Bir hata oluştu, rematch başlatılamadı.' });
        this.status = 'over';
        this._finish();
      });
      return;
    }

    this.status = 'active';
    for (let i = 0; i < 2; i++) {
      this._emitTo(i, 'rematch_accepted', {});
    }
    this._dealNewRound();
  }

  /// Bir oyuncu baglantisini kopardiginda (veya bilincli olarak masadan
  /// kalktiginda) cagrilir. MVP kapsaminda yeniden baglanma
  /// desteklenmiyor: kopan oyuncu hemen kaybetmis sayilir.
  handlePlayerGone(socketId, { voluntary } = { voluntary: false }) {
    const index = this.indexOfSocket(socketId);
    if (index === -1) return;
    if (this.status === 'over') {
      // Oyun bitmis, rematch bekleme surecindeydi: rakip hala
      // bagliysa haberdar edip odayi kapatiyoruz.
      this.players[index].connected = false;
      const oppIndex = 1 - index;
      const opponent = this.players[oppIndex];
      if (opponent && opponent.connected) {
        this._emitTo(oppIndex, 'opponent_left', {});
      }
      this._finish();
      return;
    }

    this.players[index].connected = false;

    if (this.status === 'waiting') {
      // Rakip henuz katilmamisti; oda anlamsizlasti. Giris ucreti henuz
      // hic alinmadi (start() cagrilmadi), iade gerekmiyor.
      this.status = 'over';
      this._finish();
      return;
    }

    this._clearRoundTimer();
    this.status = 'over';
    const oppIndex = 1 - index;
    const opponent = this.players[oppIndex];
    if (opponent && opponent.connected) {
      if (!voluntary) this._emitTo(oppIndex, 'opponent_left', {});
      this._emitTo(oppIndex, 'game_over', {
        youWon: true,
        yourScore: opponent.score,
        opponentScore: this.players[index].score,
        reason: voluntary ? 'opponent_left' : 'opponent_disconnected',
      });
    }

    // Rakip masadan kalkti/koptu: kalan oyuncu havuzun tamamini alir
    // (bkz. sinif dokumani). _finish() cagrilmadan once bekleniyor ki
    // odeme tamamlanmadan oda silinmesin.
    this._settleWallets(opponent && opponent.connected ? oppIndex : null).finally(() => {
      this._finish();
    });
    return;
  }

  _clearRoundTimer() {
    if (this._timeoutHandle) clearTimeout(this._timeoutHandle);
    this._timeoutHandle = null;
  }

  _clearTimers() {
    this._clearRoundTimer();
    if (this._nextRoundHandle) clearTimeout(this._nextRoundHandle);
    if (this._gameOverHandle) clearTimeout(this._gameOverHandle);
    if (this._rematchGraceHandle) clearTimeout(this._rematchGraceHandle);
    this._nextRoundHandle = null;
    this._gameOverHandle = null;
    this._rematchGraceHandle = null;
  }

  _finish() {
    this._clearTimers();
    if (this.onFinished) this.onFinished(this.id);
  }

  destroy() {
    this._clearTimers();
  }
}

module.exports = Room;
