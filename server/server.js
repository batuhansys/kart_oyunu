const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const RoomManager = require('./game/roomManager');
const { getAuth, getFirestore } = require('./firebaseAdmin');
const { payReward } = require('./game/wallet');
const { claimLevelRewards } = require('./game/leveling');
const { SHOP_PACKAGES } = require('./game/shopPackages');
const { spinWheel } = require('./game/dailyWheel');
const { mergeFragments, openChest } = require('./game/workshop');

const app = express();
const server = http.createServer(app);
app.use(express.json());

// Socket.IO'nun cors ayari sadece soket handshake'ini kapsar; asagidaki
// /api/* uclarina web build'den (farkli origin) yapilan fetch/POST
// istekleri icin Express'in kendi CORS basliklari gerekiyor.
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') {
    res.sendStatus(204);
    return;
  }
  next();
});

// origin: '*' -> gelistirme/MVP asamasi icin herkese acik. Ileride kendi
// domaininizi biliyorsaniz bunu o domainle sinirlayabilirsiniz.
const io = new Server(server, {
  cors: { origin: '*' },
});

// Client baglanirken Firebase ID token'ini `auth: { token }` ile gonderir
// (bkz. lib/core/network/socket_service.dart). Token dogrulanabilirse
// socket.data.uid gercek, sahtesi yapilamaz bir kimlige baglanir — sehirli
// (giris ucretli) maclarda cuzdan islemleri SADECE bu uid uzerinden
// yapilir. Token yoksa/gecersizse baglanti reddedilmez (misafir olarak
// devam eder) ama socket.data.uid null kalir; Room.start() bunu
// kontrol edip sehirli maclara girisi engeller (bkz. server/game/room.js).
io.use(async (socket, next) => {
  const token = socket.handshake.auth?.token;
  if (!token) {
    socket.data.uid = null;
    return next();
  }
  try {
    const decoded = await getAuth().verifyIdToken(token);
    socket.data.uid = decoded.uid;
  } catch (err) {
    console.warn('[auth] gecersiz Firebase ID token, misafir olarak baglaniliyor:', err.message);
    socket.data.uid = null;
  }
  next();
});

// Render/Railway gibi platformlar saglik kontrolu icin '/' adresine
// istek atar; ayrica tarayicidan adresi acinca sunucunun ayakta oldugunu
// gormek icin kullanislidir.
app.get('/', (_req, res) => {
  res.send('RISK Get and Gain multiplayer sunucusu calisiyor.');
});

// REST uclarini korur: Authorization: Bearer <Firebase ID token> bekler,
// gecerliyse req.uid'i set eder. Soket baglantisindaki io.use middleware'iyle
// ayni dogrulamayi yapar (bkz. yukarisi) - burada ise misafir gecisi YOK,
// token yoksa/gecersizse istek reddedilir (ekonomi uclari kimliksiz asla
// calismamali).
async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: 'Yetkisiz istek.' });
    return;
  }
  try {
    const decoded = await getAuth().verifyIdToken(token);
    req.uid = decoded.uid;
    next();
  } catch (err) {
    console.warn('[api] gecersiz Firebase ID token:', err.message);
    res.status(401).json({ error: 'Geçersiz oturum.' });
  }
}

// Magaza satin alma: gercek odeme entegrasyonu (Google Play Billing vb.)
// sonradan baglanacak - simdilik listedeki gecerli bir paket her zaman
// onaylanir, RC dogrudan sunucu tarafindan (firebase-admin ile) hesaba
// geçirilir; client artik riskCoin'i hicbir zaman dogrudan yazamaz.
app.post('/api/shop/purchase', requireAuth, async (req, res) => {
  const amount = Number(req.body?.amount);
  const pkg = SHOP_PACKAGES.find((p) => p.amount === amount);
  if (!pkg) {
    res.status(400).json({ error: 'Geçersiz paket.' });
    return;
  }
  try {
    await payReward(req.uid, pkg.amount);
    res.json({ ok: true, amount: pkg.amount });
  } catch (err) {
    console.error('[shop] purchase failed:', err);
    res.status(500).json({ error: 'Satın alma başarısız.' });
  }
});

// Bekleyen seviye odullerinin tamamini tek seferde hesaba geçirir.
app.post('/api/level/claim', requireAuth, async (req, res) => {
  try {
    const result = await claimLevelRewards(req.uid);
    res.json(result);
  } catch (err) {
    console.error('[level] claim failed:', err);
    res.status(500).json({ error: 'Ödül toplama başarısız.' });
  }
});

// Gunluk cark: type 'free' (gunde 1) veya 'ad' (gunde 1, sadece free
// kullanildiysa - client bu istegi ancak sahte reklam bekleme ekranini
// gosterdikten SONRA atar, bkz. lib/features/daily_wheel). Sonuc
// (hangi dilim + kazanilan RC) tamamen burada, sunucuda belirlenir.
app.post('/api/wheel/spin', requireAuth, async (req, res) => {
  const type = req.body?.type === 'ad' ? 'ad' : 'free';
  try {
    const result = await spinWheel(req.uid, type);
    if (!result.ok) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.json(result);
  } catch (err) {
    console.error('[wheel] spin failed:', err);
    res.status(500).json({ error: 'Çark çevrilemedi.' });
  }
});

// Atolye: 5 parcayi 1 sandiga donusturur.
app.post('/api/workshop/merge', requireAuth, async (req, res) => {
  const cityId = req.body?.cityId;
  try {
    const result = await mergeFragments(req.uid, cityId);
    if (!result.ok) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.json(result);
  } catch (err) {
    console.error('[workshop] merge failed:', err);
    res.status(500).json({ error: 'Birleştirme başarısız.' });
  }
});

// Atolye: 1 sandik acar, RC veya guc odulu verir.
app.post('/api/workshop/open-chest', requireAuth, async (req, res) => {
  const cityId = req.body?.cityId;
  try {
    const result = await openChest(req.uid, cityId);
    if (!result.ok) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.json(result);
  } catch (err) {
    console.error('[workshop] open-chest failed:', err);
    res.status(500).json({ error: 'Sandık açılamadı.' });
  }
});

// Royal Pass: gercek odeme entegrasyonu sonradan baglanacak (bkz. magaza
// ile ayni not) - simdilik dogrudan aktif eder. leveling.js zaten
// isRoyalPass'i okuyup seviye atlama/kilometre tasi odullerini 2x yapiyor.
app.post('/api/royal-pass/activate', requireAuth, async (req, res) => {
  try {
    await getFirestore().collection('users').doc(req.uid).update({ isRoyalPass: true });
    res.json({ ok: true });
  } catch (err) {
    console.error('[royal-pass] activate failed:', err);
    res.status(500).json({ error: 'Royal Pass etkinleştirilemedi.' });
  }
});

const roomManager = new RoomManager(io);

io.on('connection', (socket) => {
  roomManager.registerSocket(socket);

  socket.on('join_city_queue', ({ cityId, name } = {}) => roomManager.joinCityQueue(socket, cityId, name));
  socket.on('cancel_city_queue', () => roomManager.cancelCityQueue(socket));
  socket.on('create_room', ({ name, cityId } = {}) => roomManager.createPrivateRoom(socket, name, cityId));
  socket.on('join_room', ({ code, name } = {}) => roomManager.joinPrivateRoom(socket, code, name));
  socket.on('invite_friend', ({ targetUid } = {}) => roomManager.inviteFriend(socket, targetUid));
  socket.on('submit_choice', ({ choice } = {}) => roomManager.submitChoice(socket, choice));
  socket.on('use_power', ({ power } = {}) => roomManager.usePower(socket, power));
  socket.on('request_rematch', () => roomManager.requestRematch(socket));
  socket.on('accept_rematch', () => roomManager.acceptRematch(socket));
  socket.on('leave_room', () => roomManager.leaveRoom(socket));
  socket.on('disconnect', () => roomManager.handleDisconnect(socket));
});

// Onemli: Render/Railway gibi platformlar kendi PORT numarasini env
// degiskeni olarak verir; sabit bir port (orn. 3000) yazarsaniz deploy
// calismaz. Yerelde calistirinca 3000'e duser.
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Sunucu ${PORT} portunda calisiyor.`);
});
