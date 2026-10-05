process.env.OKEY_FAST = '1';
const OkeyRoom = require('../okey/room');
const { nextAction } = require('../okey/bot');
const events = [];
const io = { to: (id) => ({ emit: (ev, p) => events.push({ id, ev, p }) }) };
const room = new OkeyRoom({ id: 'T1', mode: 'private', io, city: null, onFinished: () => console.log('finished') });
room.addPlayer('s1', 'Ben', 'u1');
room.start().then(() => {
  // insan oyuncu da bot mantigiyla oynasin (otomatik pilot)
  const t = setInterval(() => {
    const g = room.game;
    if (!g || room.status === 'over') { clearInterval(t); return; }
    const idx = room.indexOfSocket('s1');
    if (!g.roundOver && g.current === idx) {
      const a = nextAction(g, idx);
      room.handleAction('s1', a);
    }
  }, 1);
  const done = setInterval(() => {
    if (room.status === 'over') {
      clearInterval(done);
      const over = events.filter((e) => e.ev === 'okey_over').pop();
      console.log('OVER', JSON.stringify(over.p.totals), JSON.stringify(over.p.ranking), 'events', events.length, 'errors', events.filter(e=>e.ev==='okey_error').length);
      process.exit(0);
    }
  }, 50);
});
setTimeout(() => { console.log('TIMEOUT', room.status, room.game && room.game.round); process.exit(1); }, 60000);
