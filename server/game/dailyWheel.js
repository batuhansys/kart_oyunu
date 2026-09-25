const { getFirestore, admin } = require('../firebaseAdmin');

/**
 * Günlük Çark: 6 dilim, her biri oyuncunun bakiyesinin bir yüzdesi kadar
 * RC verir (taban en az 10.000 RC - bakiye dusukse bile cark her zaman
 * anlamli bir odul verir). Sonuc TAMAMEN sunucuda belirlenir, client'a
 * sadece hangi dilimde durulacagi (tierIndex) ve kazanilan RC bildirilir
 * - client bunu sadece gorsel olarak o dilime dondurmek icin kullanir.
 */
const WHEEL_TIERS = [
  { percent: 0.01, probability: 0.25 },
  { percent: 0.02, probability: 0.25 },
  { percent: 0.04, probability: 0.25 },
  { percent: 0.10, probability: 0.10 },
  { percent: 0.20, probability: 0.10 },
  { percent: 0.50, probability: 0.05 },
];

const MIN_BASE_RC = 10000;

function roundUpTo100(n) {
  return Math.ceil(n / 100) * 100;
}

function pickTierIndex() {
  const r = Math.random();
  let cumulative = 0;
  for (let i = 0; i < WHEEL_TIERS.length; i++) {
    cumulative += WHEEL_TIERS[i].probability;
    if (r < cumulative) return i;
  }
  return WHEEL_TIERS.length - 1;
}

function isSameUtcDay(a, b) {
  return (
    a.getUTCFullYear() === b.getUTCFullYear() &&
    a.getUTCMonth() === b.getUTCMonth() &&
    a.getUTCDate() === b.getUTCDate()
  );
}

/** type: 'free' | 'ad'. 'free' gunde bir kere; 'ad' sadece 'free'
 * zaten kullanildiysa VE gunde bir kere. Ikisi de UTC gunune gore. */
async function spinWheel(uid, type) {
  const db = getFirestore();
  const ref = db.collection('users').doc(uid);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return { ok: false, error: 'Kullanıcı bulunamadı.' };
    const data = snap.data();
    const now = new Date();

    const lastFree = data.lastFreeSpinAt ? data.lastFreeSpinAt.toDate() : null;
    const lastAd = data.lastAdSpinAt ? data.lastAdSpinAt.toDate() : null;
    const freeUsedToday = !!(lastFree && isSameUtcDay(lastFree, now));
    const adUsedToday = !!(lastAd && isSameUtcDay(lastAd, now));

    if (type === 'free') {
      if (freeUsedToday) return { ok: false, error: 'Bugünkü ücretsiz çevirmeyi zaten kullandın.' };
    } else if (type === 'ad') {
      if (!freeUsedToday) return { ok: false, error: 'Önce ücretsiz çevirmeyi kullanmalısın.' };
      if (adUsedToday) return { ok: false, error: 'Bugünkü reklamlı çevirmeyi zaten kullandın.' };
    } else {
      return { ok: false, error: 'Geçersiz çevirme türü.' };
    }

    const balance = data.riskCoin || 0;
    const base = Math.max(balance, MIN_BASE_RC);
    const tierIndex = pickTierIndex();
    const rewardRc = roundUpTo100(base * WHEEL_TIERS[tierIndex].percent);

    const update = { riskCoin: admin.firestore.FieldValue.increment(rewardRc) };
    if (type === 'free') update.lastFreeSpinAt = admin.firestore.FieldValue.serverTimestamp();
    else update.lastAdSpinAt = admin.firestore.FieldValue.serverTimestamp();
    tx.update(ref, update);

    return { ok: true, tierIndex, rewardRc };
  });
}

module.exports = { spinWheel, WHEEL_TIERS, MIN_BASE_RC, roundUpTo100 };
