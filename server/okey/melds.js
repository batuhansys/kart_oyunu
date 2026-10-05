/**
 * Per (grup/seri/cift) analizi ve el cozucu (en yuksek puanli per dizilimi).
 *
 * Kurallar (101 Okey):
 *  - Seri: ayni renkte >=3 ardisik sayi; 1 sadece 13'ten sonra gelebilir
 *    (12-13-1 gecerli, 13-1-2 gecersiz). 1 her zaman 1 puan sayilir.
 *  - Grup: ayni sayidan, farkli renklerde 3 veya 4 tas.
 *  - Cift: ayni renk+sayida iki tas (el acarken >=5 cift gerekir).
 *  - Okey (joker) her tasin yerine gecer; puan olarak yerine gectigi tasin
 *    degerini tasir. Sahte okey, okey tasinin kendisi gibi sayilir.
 */
const { faceOf, MAX_NUMBER } = require('./tiles');

const OPEN_THRESHOLD = 101;
const MIN_PAIRS_TO_OPEN = 5;

function posValue(p) {
  return p === 14 ? 1 : p;
}

function analyzePair(faces, jokers) {
  if (faces.length === 2) {
    if (faces[0].color !== faces[1].color || faces[0].number !== faces[1].number) return null;
  }
  const ordered = [...faces.map((f) => ({ id: f.id, color: f.color, number: f.number }))];
  const anchor = faces[0] || null;
  for (const j of jokers) {
    ordered.push({ id: j.id, color: anchor ? anchor.color : -1, number: anchor ? anchor.number : 0, joker: true });
  }
  return { type: 'pair', value: 0, ordered };
}

function analyzeGroup(faces, jokers, total) {
  if (total < 3 || total > 4) return null;
  const number = faces[0].number;
  const used = new Set();
  for (const f of faces) {
    if (f.number !== number || used.has(f.color)) return null;
    used.add(f.color);
  }
  const ordered = faces.map((f) => ({ id: f.id, color: f.color, number: f.number }));
  const freeColors = [0, 1, 2, 3].filter((c) => !used.has(c));
  jokers.forEach((j, i) => {
    ordered.push({ id: j.id, color: freeColors[i] ?? -1, number, joker: true });
  });
  ordered.sort((a, b) => a.color - b.color);
  return { type: 'group', value: number * total, ordered };
}

function analyzeRun(faces, jokers, total) {
  if (total < 3 || total > MAX_NUMBER) return null;
  const color = faces[0].color;
  for (const f of faces) if (f.color !== color) return null;

  let best = null;
  for (let s = 1; s + total - 1 <= 14; s++) {
    const e = s + total - 1;
    const slots = new Array(total).fill(null);
    let ok = true;
    for (const f of faces) {
      let p = f.number;
      if (p < s || p > e) {
        if (f.number === 1 && e === 14) p = 14;
        else { ok = false; break; }
      }
      if (slots[p - s]) { ok = false; break; }
      slots[p - s] = f;
    }
    if (!ok) continue;
    const empties = slots.filter((x) => x === null).length;
    if (empties !== jokers.length) continue;
    let value = 0;
    for (let p = s; p <= e; p++) value += posValue(p);
    if (!best || value > best.value) {
      let ji = 0;
      const ordered = slots.map((f, i) => {
        const p = s + i;
        const number = p === 14 ? 1 : p;
        if (f) return { id: f.id, color, number };
        return { id: jokers[ji++].id, color, number, joker: true };
      });
      best = { type: 'run', value, ordered };
    }
  }
  return best;
}

/** tiles: tas nesneleri. Gecersizse null, gecerliyse { type, value, ordered }. */
function analyzeMeld(tiles, okey) {
  const faces = [];
  const jokers = [];
  for (const t of tiles) {
    const f = faceOf(t, okey);
    if (f) faces.push({ id: t.id, color: f.color, number: f.number });
    else jokers.push(t);
  }
  const total = tiles.length;
  if (total === 2) return analyzePair(faces, jokers);
  if (total < 3 || faces.length === 0) return null;
  const group = analyzeGroup(faces, jokers, total);
  const run = analyzeRun(faces, jokers, total);
  if (group && run) return group.value >= run.value ? group : run;
  return group || run;
}

// ---------------------------------------------------------------------------
// Cozucu: eldeki taslardan ayrik perlerin toplam puanini maksimize eder.
// ---------------------------------------------------------------------------

function buildCounts(tiles, okey) {
  const counts = new Array(52).fill(0);
  const ids = Array.from({ length: 52 }, () => []);
  const jokerIds = [];
  for (const t of tiles) {
    const f = faceOf(t, okey);
    if (!f) {
      jokerIds.push(t.id);
    } else {
      const idx = f.color * 13 + (f.number - 1);
      counts[idx]++;
      ids[idx].push(t.id);
    }
  }
  return { counts, ids, jokerIds };
}

function generateCandidates(counts, jokerCount) {
  const cands = [];
  const maxJ = Math.min(jokerCount, 2);

  for (let n = 1; n <= 13; n++) {
    const avail = [];
    for (let c = 0; c < 4; c++) if (counts[c * 13 + n - 1] > 0) avail.push(c * 13 + n - 1);
    const m = avail.length;
    for (let mask = 1; mask < 1 << m; mask++) {
      const faces = [];
      for (let b = 0; b < m; b++) if (mask & (1 << b)) faces.push(avail[b]);
      for (let j = 0; j <= maxJ; j++) {
        const tot = faces.length + j;
        if (tot >= 3 && tot <= 4) cands.push({ faces, j, value: n * tot, size: tot });
      }
    }
  }

  for (let c = 0; c < 4; c++) {
    for (let s = 1; s <= 12; s++) {
      for (let L = 3; s + L - 1 <= 14 && L <= 13; L++) {
        const faces = [];
        let need = 0;
        let value = 0;
        let realCount = 0;
        for (let p = s; p < s + L; p++) {
          const idx = c * 13 + (p === 14 ? 1 : p) - 1;
          value += posValue(p);
          if (counts[idx] > 0) { faces.push(idx); realCount++; } else need++;
        }
        if (realCount === 0 || need > maxJ) continue;
        cands.push({ faces, j: need, value, size: L });
      }
    }
  }
  return cands;
}

/**
 * Elden en yuksek puanli ayrik per kumesini bulur (once puan, sonra
 * kullanilan tas sayisi). Donus: { value, melds: [[tileId,...]], used }.
 */
function solveMelds(tiles, okey) {
  const { counts, ids, jokerIds } = buildCounts(tiles, okey);
  const cands = generateCandidates(counts, jokerIds.length);
  const byFace = Array.from({ length: 52 }, () => []);
  for (const cand of cands) for (const f of cand.faces) byFace[f].push(cand);

  const memo = new Map();
  const cur = counts.slice();

  function dfs(jLeft) {
    let first = -1;
    for (let i = 0; i < 52; i++) if (cur[i] > 0) { first = i; break; }
    if (first === -1) return { score: 0, choice: null };
    const key = cur.join('') + '|' + jLeft;
    const hit = memo.get(key);
    if (hit) return hit;

    cur[first]--;
    let best = { score: dfs(jLeft).score, choice: null };
    cur[first]++;

    for (const cand of byFace[first]) {
      if (cand.j > jLeft) continue;
      let fits = true;
      for (const f of cand.faces) if (cur[f] <= 0) { fits = false; break; }
      if (!fits) continue;
      for (const f of cand.faces) cur[f]--;
      const sub = dfs(jLeft - cand.j);
      for (const f of cand.faces) cur[f]++;
      const score = cand.value * 100 + cand.size + sub.score;
      if (score > best.score) best = { score, choice: cand };
    }
    memo.set(key, best);
    return best;
  }

  // Yeniden kurma: ayni durum uzerinden secimleri izle.
  const work = counts.slice();
  let jLeft = jokerIds.length;
  dfsInit();
  function dfsInit() {
    // cur'u baslangic haline getir ve kok sonucu hesapla.
    for (let i = 0; i < 52; i++) cur[i] = counts[i];
    dfs(jLeft);
  }

  const melds = [];
  const pool = ids.map((a) => a.slice());
  const jokerPool = jokerIds.slice();
  let value = 0;
  let used = 0;
  for (let i = 0; i < 52; i++) cur[i] = work[i];
  for (;;) {
    let first = -1;
    for (let i = 0; i < 52; i++) if (cur[i] > 0) { first = i; break; }
    if (first === -1) break;
    const res = dfs(jLeft);
    if (!res.choice) {
      cur[first]--;
      pool[first].pop();
      continue;
    }
    const cand = res.choice;
    const meld = [];
    for (const f of cand.faces) { cur[f]--; meld.push(pool[f].pop()); }
    for (let k = 0; k < cand.j; k++) meld.push(jokerPool.pop());
    jLeft -= cand.j;
    melds.push(meld);
    value += cand.value;
    used += cand.size;
  }
  return { value, melds, used };
}

/** Elde en fazla kac ayrik cift kurulabilir (joker herhangi bir tasla cift olur). */
function maxPairs(tiles, okey) {
  const { counts, jokerIds } = buildCounts(tiles, okey);
  let pairs = 0;
  let odd = 0;
  for (const c of counts) { pairs += Math.floor(c / 2); odd += c % 2; }
  let j = jokerIds.length;
  const withOdd = Math.min(j, odd);
  pairs += withOdd;
  j -= withOdd;
  pairs += Math.floor(j / 2);
  return pairs;
}

/** El acabilir mi? (101 puan veya 5+ cift) */
function canOpen(tiles, okey) {
  if (solveMelds(tiles, okey).value >= OPEN_THRESHOLD) return true;
  return maxPairs(tiles, okey) >= MIN_PAIRS_TO_OPEN;
}

module.exports = {
  OPEN_THRESHOLD,
  MIN_PAIRS_TO_OPEN,
  analyzeMeld,
  solveMelds,
  maxPairs,
  canOpen,
};
