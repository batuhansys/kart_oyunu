// SADECE TEST: insan oyuncuya 102 puanlik acilis eli verir. Kullanim:
//   node test/rig_server.js   (server.js yerine)
const OkeyRoom = require('../okey/room');
const { faceOf } = require('../okey/tiles');

function rig(game, idx) {
  const me = game.players[idx];
  const want = [[0, 11], [0, 12], [0, 13], [1, 13], [2, 13], [3, 13], [2, 8], [2, 9], [2, 10], [3, 2], [1, 1], [0, 6], [2, 4], [3, 7]];
  const containers = [...game.players.map((p) => p.hand), game.deck];
  const taken = new Set();
  const pick = (c, n) => {
    for (const arr of containers) {
      const t = arr.find((x) => !taken.has(x.id) && !x.fake && x.color === c && x.number === n && !(game.okey.color === c && game.okey.number === n));
      if (t) return { arr, t };
    }
    return null;
  };
  const newHand = [];
  const junk = me.hand.slice();
  for (const [c, n] of want) {
    const f = pick(c, n);
    if (!f) continue;
    taken.add(f.t.id);
    const j = junk.pop();
    // takas: f.t baska bir yerdeyse oraya junk'i koy
    const i = f.arr.indexOf(f.t);
    if (f.arr === me.hand) { newHand.push(f.t); continue; }
    f.arr[i] = j;
    newHand.push(f.t);
  }
  const rest = me.hand.filter((t) => !newHand.includes(t) && !taken.has(t.id));
  me.hand = [...newHand, ...rest].slice(0, me.hand.length);
}

const orig = OkeyRoom.prototype.start;
OkeyRoom.prototype.start = async function start() {
  await orig.call(this);
  if (!this.game) return;
  const idx = this.seats.findIndex((s) => s.type === 'human');
  if (idx >= 0) { rig(this.game, idx); this._broadcast(); }
};
const origEmit = OkeyRoom.prototype._emitTo;
OkeyRoom.prototype._emitTo = function emit(seat, ev, payload) {
  if (ev === 'okey_error' || ev === 'power_error') console.log('[hata]', ev, JSON.stringify(payload));
  return origEmit.call(this, seat, ev, payload);
};
const origAction = OkeyRoom.prototype.handleAction;
OkeyRoom.prototype.handleAction = function act(sid, a) {
  if (a.type !== 'draw' && a.type !== 'discard') console.log('[hamle]', JSON.stringify(a));
  return origAction.call(this, sid, a);
};
require('../server.js');
