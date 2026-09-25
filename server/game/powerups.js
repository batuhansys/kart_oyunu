const { getFirestore, admin } = require('../firebaseAdmin');

/**
 * Guc envanteri: her sandik acildiginda (bkz. workshop.js openChest)
 * kazanilan ZORBA/KALKAN/KAHIN gucleri users/{uid}.powerups altinda
 * `{ zorba: {count, expiresAt}, kalkan: {...}, kahin: {...} }` seklinde
 * tutulur. HER sehir ayni turden gucu verebilir, sadece MIKTAR ve
 * GECERLILIK SURESI sehre gore degisir (bkz. POWER_GRANTS_BY_CITY).
 * Yeni bir kazanim, suresi gecmemis mevcut adede eklenir ve gecerlilik
 * suresini o anki kazanimdan itibaren yeniler; suresi gecmis bir adet
 * kullanilamaz (0 sayilir, bkz. usableCount).
 */
const POWER_TYPES = ['zorba', 'kalkan', 'kahin'];

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

// Sadece istanbul (1/24s) ve rio (3/3gun) kullanicidan geldi; digerleri
// sehrin "tier"ina gore benim tasarimim (bkz. plan Faz 3).
const POWER_GRANTS_BY_CITY = {
  istanbul: { count: 1, durationMs: 1 * DAY },
  london: { count: 1, durationMs: 2 * DAY },
  rio: { count: 3, durationMs: 3 * DAY },
  tokyo: { count: 3, durationMs: 5 * DAY },
  lasvegas: { count: 5, durationMs: 7 * DAY },
  maras: { count: 5, durationMs: 14 * DAY },
};

function isExpired(powerEntry, now) {
  if (!powerEntry || !powerEntry.expiresAt) return true;
  const expiresAt = powerEntry.expiresAt.toDate ? powerEntry.expiresAt.toDate() : new Date(powerEntry.expiresAt);
  return now.getTime() >= expiresAt.getTime();
}

/** Kullanilabilir (suresi gecmemis) adedi doner. */
function usableCount(powerEntry, now) {
  if (isExpired(powerEntry, now)) return 0;
  return powerEntry.count || 0;
}

/** Bir sandiktan kazanilan gucu (cityId'ye gore adet/sure) envantere
 * eklemek icin gereken Firestore alan guncellemesini (dot-path) doner -
 * yazmayi cagiran (workshop.js) tek bir tx.update() icinde birlestirir. */
function powerGrantFields(currentData, powerType, cityId) {
  const grant = POWER_GRANTS_BY_CITY[cityId];
  if (!grant) return {};
  const now = new Date();
  const existing = (currentData.powerups || {})[powerType];
  const existingUsable = usableCount(existing, now);
  const newCount = existingUsable + grant.count;
  const newExpiresAt = new Date(now.getTime() + grant.durationMs);

  return {
    [`powerups.${powerType}`]: {
      count: newCount,
      expiresAt: admin.firestore.Timestamp.fromDate(newExpiresAt),
    },
  };
}

/** Bir gucu kullanir: adedi 1 dusurur. Kullanilamiyorsa false doner. */
async function consumePower(uid, powerType) {
  if (!POWER_TYPES.includes(powerType)) return false;
  const db = getFirestore();
  const ref = db.collection('users').doc(uid);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return false;
    const data = snap.data();
    const now = new Date();
    const existing = (data.powerups || {})[powerType];
    const usable = usableCount(existing, now);
    if (usable <= 0) return false;

    tx.update(ref, {
      [`powerups.${powerType}`]: { count: usable - 1, expiresAt: existing.expiresAt },
    });
    return true;
  });
}

module.exports = {
  POWER_TYPES,
  POWER_GRANTS_BY_CITY,
  powerGrantFields,
  consumePower,
  usableCount,
  isExpired,
};
