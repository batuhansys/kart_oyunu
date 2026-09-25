const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const RoomManager = require('./game/roomManager');
const { getAuth } = require('./firebaseAdmin');

const app = express();
const server = http.createServer(app);

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

const roomManager = new RoomManager(io);

io.on('connection', (socket) => {
  socket.on('join_city_queue', ({ cityId, name } = {}) => roomManager.joinCityQueue(socket, cityId, name));
  socket.on('cancel_city_queue', () => roomManager.cancelCityQueue(socket));
  socket.on('create_room', ({ name, cityId } = {}) => roomManager.createPrivateRoom(socket, name, cityId));
  socket.on('join_room', ({ code, name } = {}) => roomManager.joinPrivateRoom(socket, code, name));
  socket.on('submit_choice', ({ choice } = {}) => roomManager.submitChoice(socket, choice));
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
