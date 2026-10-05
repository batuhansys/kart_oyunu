process.env.OKEY_FAST = '1';
const test = require('node:test');
const assert = require('node:assert');
const OkeyRoom = require('../okey/room');

function makeRoom() {
  const events = [];
  const io = { to: (id) => ({ emit: (ev, p) => events.push({ id, ev, p }) }) };
  const room = new OkeyRoom({ id: 'T', mode: 'private', io, city: null, onFinished: () => {} });
  return { room, events };
}
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

test('masa 4 koltuk: 1 insan + 3 bot, durum yayinlanir', async () => {
  const { room, events } = makeRoom();
  room.addPlayer('s1', 'Ben', 'u1');
  await room.start();
  assert.strictEqual(room.seats.length, 4);
  assert.strictEqual(room.seats.filter((s) => s.type === 'bot').length, 3);
  assert.ok(events.some((e) => e.ev === 'match_found' && e.id === 's1'));
  assert.ok(events.some((e) => e.ev === 'okey_state' && e.id === 's1'));
  room.destroy();
});

test('kopan oyuncu sure icinde geri donerse koltugunu geri alir', async () => {
  const { room, events } = makeRoom();
  room.addPlayer('s1', 'Ben', 'u1');
  await room.start();
  room.handlePlayerGone('s1', { voluntary: false });
  const seat = room.seats.find((s) => s.uid === 'u1');
  assert.strictEqual(seat.connected, false);
  assert.strictEqual(seat.left, false);
  assert.strictEqual(room.reattach('s2', 'u1'), true);
  assert.strictEqual(seat.socketId, 's2');
  assert.ok(events.some((e) => e.id === 's2' && e.ev === 'okey_state'));
  room.destroy();
});

test('sure dolunca geri donus mumkun degil, bilerek ayrilan hemen cikar', async () => {
  const { room } = makeRoom();
  room.addPlayer('s1', 'Ben', 'u1');
  await room.start();
  room.handlePlayerGone('s1', { voluntary: false });
  await wait(400); // FAST modda 200ms
  assert.strictEqual(room.reattach('s2', 'u1'), false);
  room.destroy();

  const b = makeRoom();
  b.room.addPlayer('s1', 'Ben', 'u1');
  await b.room.start();
  b.room.handlePlayerGone('s1', { voluntary: true });
  assert.strictEqual(b.room.seats.find((s) => s.uid === 'u1').left, true);
  assert.strictEqual(b.room.reattach('s2', 'u1'), false);
  b.room.destroy();
});

test('bekleme odasinda sahip cikinca oda kapanir', async () => {
  const { room, events } = makeRoom();
  let finished = false;
  room.onFinished = () => { finished = true; };
  room.addPlayer('s1', 'Sahip', 'u1');
  room.addPlayer('s2', 'Misafir', 'u2');
  room.handlePlayerGone('s1');
  assert.ok(finished);
  assert.ok(events.some((e) => e.id === 's2' && e.ev === 'room_error'));
});
