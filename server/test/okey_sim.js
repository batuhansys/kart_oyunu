const { OkeyGame } = require('../okey/game');
const { nextAction } = require('../okey/bot');
function apply(game, idx, a) {
  switch (a.type) {
    case 'draw': return game.draw(idx, a.source);
    case 'lay': return game.layMelds(idx, a.groups);
    case 'add': return game.addToMeld(idx, a.tileId, a.owner, a.meld);
    case 'swap': return game.swapJoker(idx, a.tileId, a.owner, a.meld, a.jokerId);
    case 'discard': return game.discard(idx, a.tileId);
  }
}
let errs = {}, rounds = 0, wins = 0, draws = 0, maxActions = 0, open101 = 0, pairOpens = 0;
const t0 = Date.now();
for (let seed = 0; seed < +(+process.argv[2] || 10); seed++) {
  const game = new OkeyGame({ rounds: 3 });
  let guard = 0;
  while (!game.gameOver && guard++ < 5000) {
    if (game.roundOver) { rounds++; if (game.roundResult.winner == null) draws++; else wins++; game.nextRound(); continue; }
    const idx = game.current;
    const a = nextAction(game, idx);
    const r = apply(game, idx, a);
    if (!r.ok) { errs[a.type + ':' + r.error] = (errs[a.type + ':' + r.error] || 0) + 1; 
      // fallback
      const p = game.players[idx];
      if (game.phase === 'draw') game.draw(idx, 'deck'); else game.discard(idx, p.hand[0].id); }
    if (a.type==='lay' && r.ok) { if (game.players[idx].mode==='pairs') pairOpens++; else open101++; }
  }
  if (guard >= 5000) console.log('STUCK seed', seed);
  rounds++; if (game.roundResult.winner == null) draws++; else wins++;
}
console.log({ rounds, wins, draws, errs, open101, pairOpens, ms: Date.now() - t0 });
