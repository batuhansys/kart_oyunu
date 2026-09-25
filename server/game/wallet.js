const { getFirestore, admin } = require('../firebaseAdmin');

/**
 * Iki oyuncunun da sehir giris ucretini karsilayip karsilamadigini TEK
 * bir Firestore transaction icinde kontrol eder ve karsiliyorsa ikisinin
 * de bakiyesini atomik olarak duser. Yaris durumuna (ayni anda baska bir
 * odaya girmeye calisma) karsi guvenlidir — transaction ya tamamen
 * uygulanir ya da hic uygulanmaz.
 *
 * @returns {Promise<{ok: true} | {ok: false, insufficientUids: string[]}>}
 */
async function chargeEntryFee(uidA, uidB, entryFee) {
  const db = getFirestore();
  const refA = db.collection('users').doc(uidA);
  const refB = db.collection('users').doc(uidB);

  return db.runTransaction(async (tx) => {
    const [snapA, snapB] = await Promise.all([tx.get(refA), tx.get(refB)]);
    const balanceA = snapA.data()?.riskCoin ?? 0;
    const balanceB = snapB.data()?.riskCoin ?? 0;

    const insufficientUids = [];
    if (balanceA < entryFee) insufficientUids.push(uidA);
    if (balanceB < entryFee) insufficientUids.push(uidB);
    if (insufficientUids.length > 0) {
      return { ok: false, insufficientUids };
    }

    tx.update(refA, { riskCoin: admin.firestore.FieldValue.increment(-entryFee) });
    tx.update(refB, { riskCoin: admin.firestore.FieldValue.increment(-entryFee) });
    return { ok: true };
  });
}

/** Kazanana havuzun tamamini (entryFee * 2) yatirir. */
async function payReward(uid, amount) {
  const db = getFirestore();
  await db.collection('users').doc(uid).update({
    riskCoin: admin.firestore.FieldValue.increment(amount),
  });
}

/** Berabere/iki taraf da kaybetti durumunda giris ucretini iade eder. */
async function refundEntryFee(uid, entryFee) {
  return payReward(uid, entryFee);
}

module.exports = { chargeEntryFee, payReward, refundEntryFee };
