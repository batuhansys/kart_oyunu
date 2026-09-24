const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const RoomManager = require('./game/roomManager');

const app = express();
const server = http.createServer(app);

// origin: '*' -> gelistirme/MVP asamasi icin herkese acik. Ileride kendi
// domaininizi biliyorsaniz bunu o domainle sinirlayabilirsiniz.
const io = new Server(server, {
  cors: { origin: '*' },
});

// Render/Railway gibi platformlar saglik kontrolu icin '/' adresine
// istek atar; ayrica tarayicidan adresi acinca sunucunun ayakta oldugunu
// gormek icin kullanislidir.
app.get('/', (_req, res) => {
  res.send('RISK Get and Gain multiplayer sunucusu calisiyor.');
});

const roomManager = new RoomManager(io);

io.on('connection', (socket) => {
  socket.on('quick_match', ({ name } = {}) => roomManager.quickMatch(socket, name));
  socket.on('cancel_quick_match', () => roomManager.cancelQuickMatch(socket));
  socket.on('create_room', ({ name } = {}) => roomManager.createPrivateRoom(socket, name));
  socket.on('join_room', ({ code, name } = {}) => roomManager.joinPrivateRoom(socket, code, name));
  socket.on('submit_choice', ({ choice } = {}) => roomManager.submitChoice(socket, choice));
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
