const admin = require('firebase-admin');

/**
 * Firebase Admin SDK'yi tek seferlik initialize eder. Servis hesabi
 * bilgisini iki kaynaktan biri saglar:
 *  - FIREBASE_SERVICE_ACCOUNT env degiskeni (tek satirlik JSON) — Render
 *    gibi bir yere deploy edilince kullanilir.
 *  - server/serviceAccountKey.json dosyasi — yerel gelistirmede kullanilir
 *    (bkz. .gitignore, bu dosya asla commit edilmemeli).
 *
 * Ikisi de yoksa acik bir hata firlatir; sunucu Firebase'e bagimli
 * ozellikleri (sehir bazli esleme, cuzdan) kullanmadan da ayaga kalkabilsin
 * diye bu modul sadece ihtiyac duyuldugunda (lazy) import edilir.
 */
let app = null;

function getFirebaseApp() {
  if (app) return app;

  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  let credential;
  if (raw) {
    credential = admin.credential.cert(JSON.parse(raw));
  } else {
    // eslint-disable-next-line global-require, import/no-dynamic-require
    const serviceAccount = require('./serviceAccountKey.json');
    credential = admin.credential.cert(serviceAccount);
  }

  app = admin.initializeApp({ credential });
  return app;
}

function getFirestore() {
  getFirebaseApp();
  return admin.firestore();
}

function getAuth() {
  getFirebaseApp();
  return admin.auth();
}

module.exports = { getFirebaseApp, getFirestore, getAuth, admin };
