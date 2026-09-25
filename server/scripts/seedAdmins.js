/**
 * Test icin Admin1/Admin2 hesaplarini olusturur (Firebase Auth kullanicisi
 * + users/{uid} Firestore profili, yuksek RC bakiyesiyle). Idempotent'tir:
 * hesap zaten varsa sadece profilini/bakiyesini gunceller, tekrar
 * calistirmak guvenlidir.
 *
 * Kullanim: server/serviceAccountKey.json yerinde iken (veya
 * FIREBASE_SERVICE_ACCOUNT env'i set edilmisken)
 *   node server/scripts/seedAdmins.js
 */
const { getAuth, getFirestore, admin } = require('../firebaseAdmin');

const ADMIN_STARTING_RC = 999999999;

const ADMIN_ACCOUNTS = [
  { username: 'Admin1', password: 'RiskAdmin1!' },
  { username: 'Admin2', password: 'RiskAdmin2!' },
];

function emailFor(username) {
  return `${username.toLowerCase()}@kartoyunu.app`;
}

async function ensureAuthUser(auth, { username, password }) {
  const email = emailFor(username);
  try {
    return await auth.getUserByEmail(email);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
    return auth.createUser({ email, password, displayName: username });
  }
}

async function seedOne(auth, db, account) {
  const userRecord = await ensureAuthUser(auth, account);
  const usernameLower = account.username.toLowerCase();

  await db.collection('usernames').doc(usernameLower).set({ uid: userRecord.uid });

  await db.collection('users').doc(userRecord.uid).set(
    {
      username: account.username,
      usernameLower,
      email: emailFor(account.username),
      level: 99,
      xp: 0,
      riskCoin: ADMIN_STARTING_RC,
      isAdmin: true,
      friendUids: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log(`ok: ${account.username} -> uid=${userRecord.uid}, email=${emailFor(account.username)}`);
}

async function main() {
  const auth = getAuth();
  const db = getFirestore();

  for (const account of ADMIN_ACCOUNTS) {
    // eslint-disable-next-line no-await-in-loop
    await seedOne(auth, db, account);
  }

  console.log('\nTamamlandi. Giris ekraninda kullanici adi olarak Admin1 / Admin2, sifre olarak yukaridaki sifreleri kullanin.');
  process.exit(0);
}

main().catch((err) => {
  console.error('seedAdmins basarisiz:', err);
  process.exit(1);
});
