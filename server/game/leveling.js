const { getFirestore, admin } = require('../firebaseAdmin');

/**
 * Seviye/XP sistemi. Tum yazmalar firebase-admin (bu kurallari hic
 * gormeden) uzerinden, transaction icinde yapilir - client asla dogrudan
 * xp/level/pendingLevelRewards yazamaz (bkz. firestore.rules).
 *
 * Seviye egrisi: L seviyesinden L+1'e gecmek icin gereken XP = 1000 * L.
 * Maksimum seviye 99 - bu seviyeye ulasilinca fazla XP atilir (xp=0'da
 * sabitlenir), daha fazla ilerleme yok.
 *
 * Odul aninda hesaba gecmez: her seviye atlaminda (ve her 10 seviyede
 * bir ekstra kilometre tasi odulunde) pendingLevelRewards dizisine bir
 * kayit eklenir; oyuncu bunlari /api/level/claim ile toplar (bkz.
 * lib/features/level_rewards).
 */
const MAX_LEVEL = 99;
const MAX_LEVEL_BONUS_RC = 50000;

function xpForLevel(level) {
  return 1000 * level;
}

function levelUpRewardRc(newLevel, isRoyalPass) {
  const base = 100 * newLevel;
  return isRoyalPass ? base * 2 : base;
}

function milestoneRewardRc(newLevel, isRoyalPass) {
  const base = 1000 * (newLevel / 10);
  return isRoyalPass ? base * 2 : base;
}

/** Bir maç kazanildiginda cagrilir; xpGained kadar XP ekler, gerekirse
 * birden fazla seviye atlatir ve her atlamada pendingLevelRewards'a
 * yeni bir odul kaydi ekler. */
async function awardXp(uid, xpGained) {
  if (!uid || !xpGained || xpGained <= 0) return;
  const db = getFirestore();
  const ref = db.collection('users').doc(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const data = snap.data() || {};

    let level = data.level || 1;
    let xp = (data.xp || 0) + xpGained;
    const isRoyalPass = !!data.isRoyalPass;
    const pending = Array.isArray(data.pendingLevelRewards) ? data.pendingLevelRewards.slice() : [];
    const now = Date.now();

    while (level < MAX_LEVEL) {
      const needed = xpForLevel(level);
      if (xp < needed) break;
      xp -= needed;
      level += 1;

      pending.push({
        id: `lvl${level}-${now}-${pending.length}`,
        level,
        rc: levelUpRewardRc(level, isRoyalPass),
        kind: 'levelup',
      });

      if (level % 10 === 0) {
        pending.push({
          id: `mil${level}-${now}-${pending.length}`,
          level,
          rc: milestoneRewardRc(level, isRoyalPass),
          kind: 'milestone',
        });
      }

      if (level === MAX_LEVEL) {
        pending.push({
          id: `max-${now}`,
          level,
          rc: isRoyalPass ? MAX_LEVEL_BONUS_RC * 2 : MAX_LEVEL_BONUS_RC,
          kind: 'maxlevel',
        });
        xp = 0;
      }
    }

    tx.update(ref, { level, xp, pendingLevelRewards: pending });
  });
}

/** Bekleyen tum seviye odullerini tek seferde hesaba gecirir ve listeyi
 * bosaltir. Odenen toplam RC ve toplanan odul listesini dondurur. */
async function claimLevelRewards(uid) {
  const db = getFirestore();
  const ref = db.collection('users').doc(uid);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return { claimed: [], totalRc: 0 };
    const data = snap.data() || {};
    const pending = Array.isArray(data.pendingLevelRewards) ? data.pendingLevelRewards : [];
    if (pending.length === 0) return { claimed: [], totalRc: 0 };

    const totalRc = pending.reduce((sum, r) => sum + (r.rc || 0), 0);
    tx.update(ref, {
      riskCoin: admin.firestore.FieldValue.increment(totalRc),
      pendingLevelRewards: [],
    });
    return { claimed: pending, totalRc };
  });
}

module.exports = { MAX_LEVEL, xpForLevel, awardXp, claimLevelRewards };
