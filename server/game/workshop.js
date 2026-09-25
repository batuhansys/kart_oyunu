const { getFirestore, admin } = require('../firebaseAdmin');
const { getCity } = require('./cities');
const { powerGrantFields } = require('./powerups');

const MAX_FRAGMENTS_PER_CITY = 50;
const FRAGMENTS_PER_CHEST = 5;

// Sandik odul tablosu: olasiliklar kullanicidan gelmedi (Claude'un
// varsayilani, bkz. plan Faz 3). Toplam %100.
const CHEST_REWARD_TABLE = [
  { type: 'rc', multiplier: 1, probability: 0.25 },
  { type: 'rc', multiplier: 2, probability: 0.20 },
  { type: 'rc', multiplier: 5, probability: 0.10 },
  { type: 'power', power: 'zorba', probability: 0.15 },
  { type: 'power', power: 'kalkan', probability: 0.15 },
  { type: 'power', power: 'kahin', probability: 0.15 },
];

function pickChestReward() {
  const r = Math.random();
  let cumulative = 0;
  for (const entry of CHEST_REWARD_TABLE) {
    cumulative += entry.probability;
    if (r < cumulative) return entry;
  }
  return CHEST_REWARD_TABLE[CHEST_REWARD_TABLE.length - 1];
}

/** Bir sehirde galibiyet kazanildiginda (sadece sehir kuyrugu macinda,
 * bkz. room.js _settleWallets) cagirilir: +1 parca, 50'de sabitlenir. */
async function awardFragment(uid, cityId) {
  if (!uid || !getCity(cityId)) return;
  const db = getFirestore();
  const ref = db.collection('users').doc(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const data = snap.data();
    const current = (data.fragments || {})[cityId] || 0;
    if (current >= MAX_FRAGMENTS_PER_CITY) return;
    tx.update(ref, { [`fragments.${cityId}`]: current + 1 });
  });
}

/** 5 parcayi 1 sandiga donusturur. */
async function mergeFragments(uid, cityId) {
  if (!getCity(cityId)) return { ok: false, error: 'Geçersiz şehir.' };
  const db = getFirestore();
  const ref = db.collection('users').doc(uid);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return { ok: false, error: 'Kullanıcı bulunamadı.' };
    const data = snap.data();
    const fragments = (data.fragments || {})[cityId] || 0;
    if (fragments < FRAGMENTS_PER_CHEST) return { ok: false, error: 'Yeterli parça yok.' };
    const chests = (data.chests || {})[cityId] || 0;

    tx.update(ref, {
      [`fragments.${cityId}`]: fragments - FRAGMENTS_PER_CHEST,
      [`chests.${cityId}`]: chests + 1,
    });
    return { ok: true };
  });
}

/** Bir sandigi acar: RC veya guc odulu verir (bkz. CHEST_REWARD_TABLE). */
async function openChest(uid, cityId) {
  const city = getCity(cityId);
  if (!city) return { ok: false, error: 'Geçersiz şehir.' };

  const db = getFirestore();
  const ref = db.collection('users').doc(uid);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return { ok: false, error: 'Kullanıcı bulunamadı.' };
    const data = snap.data();
    const chests = (data.chests || {})[cityId] || 0;
    if (chests <= 0) return { ok: false, error: 'Açılacak sandık yok.' };

    const reward = pickChestReward();
    const update = { [`chests.${cityId}`]: chests - 1 };
    let result;

    if (reward.type === 'rc') {
      const rc = city.entryFee * reward.multiplier;
      update.riskCoin = admin.firestore.FieldValue.increment(rc);
      result = { ok: true, rewardType: 'rc', rc };
    } else {
      Object.assign(update, powerGrantFields(data, reward.power, cityId));
      result = { ok: true, rewardType: 'power', power: reward.power };
    }

    tx.update(ref, update);
    return result;
  });
}

module.exports = {
  MAX_FRAGMENTS_PER_CITY,
  FRAGMENTS_PER_CHEST,
  CHEST_REWARD_TABLE,
  awardFragment,
  mergeFragments,
  openChest,
};
