/**
 * Okey botu. Oda, siradaki bot icin tek tek `nextAction` ister ve donen
 * hamleyi uygular (aralarda gecikme koyarak insan gibi hissettirir).
 * Hamleler: { type: 'draw', source } | { type: 'lay', groups } |
 * { type: 'add', tileId, owner, meld } | { type: 'swap', ... } |
 * { type: 'discard', tileId }.
 */
const { isJoker, faceOf } = require('./tiles');
const { solveMelds, maxPairs, canOpen, analyzeMeld, OPEN_THRESHOLD } = require('./melds');

function connectivity(tiles, okey) {
  // Elde per olmayan taslarin birbirine yakinligi (per potansiyeli).
  const faces = tiles.map((t) => faceOf(t, okey)).filter(Boolean);
  let score = 0;
  for (let i = 0; i < faces.length; i++) {
    for (let j = i + 1; j < faces.length; j++) {
      const a = faces[i];
      const b = faces[j];
      if (a.color === b.color) {
        const d = Math.abs(a.number - b.number);
        const wrap = (a.number === 1 && b.number === 13) || (a.number === 13 && b.number === 1);
        if (d === 0) score += 2; // cift
        else if (d === 1 || wrap) score += 3;
        else if (d === 2) score += 1.5;
      } else if (a.number === b.number) {
        score += 2;
      }
    }
  }
  return score;
}

function leftoverSum(tiles, okey) {
  let s = 0;
  for (const t of tiles) s += isJoker(t, okey) ? 25 : (faceOf(t, okey) || { number: 0 }).number;
  return s;
}

function evalHand(tiles, okey, opened) {
  const sol = solveMelds(tiles, okey);
  const meldIds = new Set(sol.melds.flat());
  const rest = tiles.filter((t) => !meldIds.has(t.id));
  const conn = connectivity(rest, okey);
  const pairBonus = opened ? 0 : maxPairs(tiles, okey) * 2;
  return sol.value * 2 + sol.used * 3 + conn * 4 + pairBonus - leftoverSum(rest, okey) * 0.4;
}

function chooseDiscard(player, okey, rng) {
  let best = null;
  for (const t of player.hand) {
    const rest = player.hand.filter((x) => x !== t);
    let score = evalHand(rest, okey, player.opened) + rng() * 0.8;
    if (isJoker(t, okey)) score -= 500;
    if (!best || score > best.score) best = { score, tile: t };
  }
  return best.tile;
}

/** Elden acilabilecek per gruplari (id dizileri) ya da null. */
function planOpening(player, okey, forceTileId) {
  const sol = solveMelds(player.hand, okey);
  if (sol.value >= OPEN_THRESHOLD) {
    if (forceTileId == null || sol.melds.flat().includes(forceTileId)) return sol.melds;
  }
  if (maxPairs(player.hand, okey) >= 5 && forceTileId == null) {
    return planPairs(player.hand, okey);
  }
  return null;
}

function planPairs(hand, okey) {
  const byFace = new Map();
  const jokers = [];
  for (const t of hand) {
    const f = faceOf(t, okey);
    if (!f) { jokers.push(t); continue; }
    const k = f.color * 13 + f.number;
    if (!byFace.has(k)) byFace.set(k, []);
    byFace.get(k).push(t);
  }
  const pairs = [];
  const singles = [];
  for (const arr of byFace.values()) {
    while (arr.length >= 2) pairs.push([arr.pop().id, arr.pop().id]);
    if (arr.length === 1) singles.push(arr[0]);
  }
  while (jokers.length && singles.length) pairs.push([singles.pop().id, jokers.pop().id]);
  while (jokers.length >= 2) pairs.push([jokers.pop().id, jokers.pop().id]);
  return pairs;
}

function nextAction(game, idx, rng = Math.random) {
  const player = game.players[idx];
  const okey = game.okey;

  if (game.phase === 'draw') {
    const prev = game.players[(idx + game.playerCount - 1) % game.playerCount];
    const top = prev.discards[prev.discards.length - 1];
    if (top) {
      const hypo = [...player.hand, top];
      const allowed = player.opened || canOpen(hypo, okey);
      if (allowed) {
        const before = solveMelds(player.hand, okey);
        const after = solveMelds(hypo, okey);
        const helps = after.used > before.used || isJoker(top, okey);
        const opens = !player.opened && after.value >= OPEN_THRESHOLD && after.melds.flat().includes(top.id);
        if (player.opened ? helps : opens) return { type: 'draw', source: 'discard' };
      }
    }
    return { type: 'draw', source: 'deck' };
  }

  // phase === 'play'
  if (!player.opened) {
    const plan = planOpening(player, okey, game.mustOpenTileId);
    if (plan && plan.length) return { type: 'lay', groups: plan };
  } else if (player.mode === 'melds') {
    // Okey degistir
    for (const owner of game.players) {
      const oi = game.players.indexOf(owner);
      for (let mi = 0; mi < owner.melds.length; mi++) {
        const meld = owner.melds[mi];
        if (meld.type === 'pair') continue;
        for (const jk of meld.tiles.filter((t) => isJoker(t, okey))) {
          for (const t of player.hand) {
            if (isJoker(t, okey)) continue;
            const a = analyzeMeld(meld.tiles.filter((x) => x !== jk).concat(t), okey);
            if (a && a.type === meld.type) return { type: 'swap', tileId: t.id, owner: oi, meld: mi, jokerId: jk.id };
          }
        }
      }
    }
    // Yeni per indir
    const sol = solveMelds(player.hand, okey);
    if (sol.melds.length) {
      const all = sol.melds.flat().length >= player.hand.length;
      if (all || player.hand.length - sol.melds.flat().length >= 1) return { type: 'lay', groups: sol.melds };
    }
    // Tas isle
    for (const t of player.hand) {
      if (player.hand.length <= 1) break;
      for (let oi = 0; oi < game.playerCount; oi++) {
        const owner = game.players[oi];
        for (let mi = 0; mi < owner.melds.length; mi++) {
          const meld = owner.melds[mi];
          if (meld.type === 'pair') continue;
          const a = analyzeMeld([...meld.tiles, t], okey);
          if (a && a.type === meld.type) return { type: 'add', tileId: t.id, owner: oi, meld: mi };
        }
      }
    }
  } else if (player.mode === 'pairs') {
    const pairs = planPairs(player.hand, okey);
    if (pairs.length && player.hand.length - pairs.length * 2 >= 0) return { type: 'lay', groups: pairs };
  }

  const tile = chooseDiscard(player, okey, rng);
  return { type: 'discard', tileId: tile.id };
}

module.exports = { nextAction, evalHand, planOpening, planPairs };
