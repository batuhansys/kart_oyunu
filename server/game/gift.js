const { getFirestore, admin } = require('../firebaseAdmin');

/**
 * Arkadasa hediye: gonderen 24 saatte 1 kez bir arkadasina GIFT_AMOUNT RC
 * hediye eder. Tutar gonderenin bakiyesinden DUSMEZ (sunucu verir). Hem
 * arkadaslik (friendRequests, status=accepted) hem sogutma suresi tek bir
 * Firestore transaction icinde kontrol edilir; istemci hicbir sey belirlemez.
 */
const GIFT_AMOUNT = 500;
const COOLDOWN_MS = 24 * 60 * 60 * 1000;

function requestId(a, b) {
  const sorted = [a, b].sort();
  return `${sorted[0]}_${sorted[1]}`;
}

function formatRemaining(ms) {
  const totalMinutes = Math.ceil(ms / 60000);
  const h = Math.floor(totalMinutes / 60);
  const m = totalMinutes % 60;
  return h > 0 ? `${h} sa ${m} dk` : `${m} dk`;
}

async function sendGift(fromUid, toUid) {
  if (typeof toUid !== 'string' || !toUid) return { ok: false, error: 'Geçersiz arkadaş.' };
  if (toUid === fromUid) return { ok: false, error: 'Kendine hediye gönderemezsin.' };

  const db = getFirestore();
  const fromRef = db.collection('users').doc(fromUid);
  const toRef = db.collection('users').doc(toUid);
  const friendRef = db.collection('friendRequests').doc(requestId(fromUid, toUid));

  return db.runTransaction(async (tx) => {
    const [fromSnap, toSnap, friendSnap] = await Promise.all([tx.get(fromRef), tx.get(toRef), tx.get(friendRef)]);
    if (!fromSnap.exists || !toSnap.exists) return { ok: false, error: 'Kullanıcı bulunamadı.' };

    const friendData = friendSnap.exists ? friendSnap.data() : null;
    const isFriend = !!friendData
      && friendData.status === 'accepted'
      && [friendData.fromUid, friendData.toUid].sort().join('_') === requestId(fromUid, toUid);
    if (!isFriend) return { ok: false, error: 'Sadece arkadaşlarına hediye gönderebilirsin.' };

    const last = fromSnap.data().lastGiftAt ? fromSnap.data().lastGiftAt.toDate().getTime() : 0;
    const remaining = last + COOLDOWN_MS - Date.now();
    if (remaining > 0) {
      return { ok: false, error: `Bir sonraki hediye için ${formatRemaining(remaining)} beklemelisin.`, remainingMs: remaining };
    }

    tx.update(fromRef, { lastGiftAt: admin.firestore.FieldValue.serverTimestamp() });
    tx.update(toRef, { riskCoin: admin.firestore.FieldValue.increment(GIFT_AMOUNT) });
    return { ok: true, amount: GIFT_AMOUNT };
  });
}

module.exports = { sendGift, GIFT_AMOUNT, COOLDOWN_MS };
