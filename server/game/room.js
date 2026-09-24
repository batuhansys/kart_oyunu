const { randomCard } = require('./cards');
const { calculateRound } = require('./scoring');
const {
  WIN_SCORE_THRESHOLD,
  LOSE_SCORE_THRESHOLD,
  MAX_CONSECUTIVE_PASSES,
  DECISION_SECONDS,
  RESULT_DISPLAY_SECONDS,
} = require('./constants');

const VALID_CHOICES = new Set(['risk', 'doubleRisk', 'pass']);

/**
 * Tek bir esleşmenin (2 oyuncu) tum state machine'ini ve zamanlayicilarini
 * yonetir. lib/state/game/game_notifier.dart + game_state.dart'in iki
 * gercek insan oyuncu icin sunucu tarafi karsiligidir.
 *
 * Onemli fark: orijinal tek-oyunculu oyunda "kim once secer" diye bir
 * sira vardi (AI, kullanicinin secimini "gorerek" karar veriyordu).
 * Iki gercek oyuncu icin buna gerek yok: ikisi de ayni anda, birbirinin
 * secimini gormeden karar verir; sunucu ikisi de secince (veya sure
 * dolunca) sonucu ayni anda acar. Bu yuzden burada "ilk oyuncu" kavrami
 * yoktur.
 */
class Room {
  constructor({ id, mode, io, onFinished }) {
    this.id = id;
    this.mode = mode; // 'private' | 'quick'
    this.io = io;
    this.onFinished = onFinished; // (roomId) => void, manager temizligi icin

    this.players = []; // [{ socketId, name, score, consecutivePasses, connected }]
    this.status = 'waiting'; // 'waiting' | 'active' | 'over'
    this.roundId = 0;
    this.cards = [null, null];
    this.choices = [null, null];
    this.tieBreakRound = false;

    this._timeoutHandle = null;
    this._nextRoundHandle = null;
  }

  get isFull() {
    return this.players.length >= 2;
  }

  addPlayer(socketId, name) {
    const index = this.players.length;
    this.players.push({
      socketId,
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

  /// Iki oyuncu da odaya katilinca cagrilir; esleşme bilgisini gonderip
  /// ilk eli dagitir.
  start() {
    this.status = 'active';
    for (let i = 0; i < 2; i++) {
      const opponent = this.players[1 - i];
      this._emitTo(i, 'match_found', {
        roomId: this.id,
        myIndex: i,
        opponentName: opponent.name,
      });
    }
    this._dealNewRound();
  }

  _dealNewRound() {
    if (this.status !== 'active') return;

    this.roundId += 1;
    this.cards = [randomCard(), randomCard()];
    this.choices = [null, null];

    if (this._timeoutHandle) clearTimeout(this._timeoutHandle);
    this._timeoutHandle = setTimeout(() => this._onRoundTimeout(), DECISION_SECONDS * 1000);

    for (let i = 0; i < 2; i++) {
      this._emitTo(i, 'round_start', { roundId: this.roundId, yourCard: this.cards[i] });
    }
  }

  submitChoice(socketId, choice) {
    if (this.status !== 'active') return;
    const index = this.indexOfSocket(socketId);
    if (index === -1) return;
    if (this.choices[index] !== null) return; // zaten secim yapmis
    if (!VALID_CHOICES.has(choice)) return;

    const player = this.players[index];
    if (choice === 'pass' && player.consecutivePasses >= MAX_CONSECUTIVE_PASSES) {
      return; // gecersiz istek (istemci normalde bu butonu zaten kapatir)
    }

    this.choices[index] = choice;
    this._emitTo(1 - index, 'opponent_choice_made', {});

    if (this.choices[0] !== null && this.choices[1] !== null) {
      if (this._timeoutHandle) clearTimeout(this._timeoutHandle);
      this._resolveRound();
    }
  }

  _onRoundTimeout() {
    for (let i = 0; i < 2; i++) {
      if (this.choices[i] === null) this.choices[i] = 'timeout';
    }
    this._resolveRound();
  }

  _resolveRound() {
    const { deltaA, deltaB } = calculateRound({
      cardA: this.cards[0],
      choiceA: this.choices[0],
      cardB: this.cards[1],
      choiceB: this.choices[1],
    });
    const deltas = [deltaA, deltaB];

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
      this.status = 'over';
      for (let i = 0; i < 2; i++) {
        const opp = 1 - i;
        this._emitTo(i, 'game_over', {
          youWon: winnerIndex === null ? null : winnerIndex === i,
          yourScore: this.players[i].score,
          opponentScore: this.players[opp].score,
          reason: 'score',
        });
      }
      this._finish();
    } else {
      this._nextRoundHandle = setTimeout(() => this._dealNewRound(), RESULT_DISPLAY_SECONDS * 1000);
    }
  }

  /// Bir oyuncu baglantisini kopardiginda (veya bilincli olarak masadan
  /// kalktiginda) cagrilir. MVP kapsaminda yeniden baglanma
  /// desteklenmiyor: kopan oyuncu hemen kaybetmis sayilir.
  handlePlayerGone(socketId, { voluntary } = { voluntary: false }) {
    const index = this.indexOfSocket(socketId);
    if (index === -1) return;
    if (this.status === 'over') return;

    this.players[index].connected = false;

    if (this.status === 'waiting') {
      // Rakip henuz katilmamisti; oda anlamsizlasti.
      this.status = 'over';
      this._finish();
      return;
    }

    this._clearTimers();
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
    this._finish();
  }

  _clearTimers() {
    if (this._timeoutHandle) clearTimeout(this._timeoutHandle);
    if (this._nextRoundHandle) clearTimeout(this._nextRoundHandle);
    this._timeoutHandle = null;
    this._nextRoundHandle = null;
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
