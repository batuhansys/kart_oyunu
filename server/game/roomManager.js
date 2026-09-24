const Room = require('./room');

// Kod okurken karistirilabilecek karakterler (0/O, 1/I/L) haric tutuldu.
const CODE_CHARSET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 5;

/**
 * Tum aktif odalari, oda-kodu -> oda esleşmesini, oyuncu socket'i -> oda
 * esleşmesini ve "hizli eslesme" bekleme kuyrugunu yonetir. server.js
 * buradaki metodlari socket olaylarina bagli olarak cagirir; bu sinif
 * socket.io olay isimlerinden habersizdir (sadece io.to(...).emit kullanir).
 */
class RoomManager {
  constructor(io) {
    this.io = io;
    this.rooms = new Map(); // code -> Room
    this.playerRoom = new Map(); // socketId -> code
    this.quickQueue = []; // [{ socketId, name }]
  }

  _generateCode() {
    let code;
    do {
      code = '';
      for (let i = 0; i < CODE_LENGTH; i++) {
        code += CODE_CHARSET[Math.floor(Math.random() * CODE_CHARSET.length)];
      }
    } while (this.rooms.has(code));
    return code;
  }

  _isAlreadyPlaying(socket) {
    if (this.playerRoom.has(socket.id)) {
      socket.emit('room_error', { message: 'Zaten bir oyunun icindesiniz.' });
      return true;
    }
    return false;
  }

  createPrivateRoom(socket, name) {
    if (this._isAlreadyPlaying(socket)) return;

    const code = this._generateCode();
    const room = new Room({
      id: code,
      mode: 'private',
      io: this.io,
      onFinished: (id) => this._onRoomFinished(id),
    });
    room.addPlayer(socket.id, name);
    this.rooms.set(code, room);
    this.playerRoom.set(socket.id, code);
    socket.emit('room_created', { code });
  }

  joinPrivateRoom(socket, rawCode, name) {
    if (this._isAlreadyPlaying(socket)) return;

    const code = (rawCode || '').toString().trim().toUpperCase();
    const room = this.rooms.get(code);
    if (!room) {
      socket.emit('room_error', { message: 'Oda bulunamadi. Kodu kontrol edin.' });
      return;
    }
    if (room.status !== 'waiting' || room.isFull) {
      socket.emit('room_error', { message: 'Bu oda artik uygun degil.' });
      return;
    }

    room.addPlayer(socket.id, name);
    this.playerRoom.set(socket.id, code);
    room.start();
  }

  quickMatch(socket, name) {
    if (this._isAlreadyPlaying(socket)) return;

    // Kuyrukta bekleyen (ve hala bagli olan) birini bul.
    while (this.quickQueue.length > 0) {
      const waiting = this.quickQueue.shift();
      if (waiting.socketId === socket.id) continue; // ayni oyuncu iki kez tiklamis olabilir
      const waitingSocket = this.io.sockets.sockets.get(waiting.socketId);
      if (!waitingSocket) continue; // kopmus, atla

      const code = this._generateCode();
      const room = new Room({
        id: code,
        mode: 'quick',
        io: this.io,
        onFinished: (id) => this._onRoomFinished(id),
      });
      room.addPlayer(waiting.socketId, waiting.name);
      room.addPlayer(socket.id, name);
      this.rooms.set(code, room);
      this.playerRoom.set(waiting.socketId, code);
      this.playerRoom.set(socket.id, code);
      room.start();
      return;
    }

    this.quickQueue.push({ socketId: socket.id, name });
    socket.emit('searching', {});
  }

  cancelQuickMatch(socket) {
    this.quickQueue = this.quickQueue.filter((q) => q.socketId !== socket.id);
  }

  submitChoice(socket, choice) {
    const code = this.playerRoom.get(socket.id);
    if (!code) return;
    const room = this.rooms.get(code);
    if (!room) return;
    room.submitChoice(socket.id, choice);
  }

  leaveRoom(socket) {
    const code = this.playerRoom.get(socket.id);
    if (!code) return;
    const room = this.rooms.get(code);
    if (room) room.handlePlayerGone(socket.id, { voluntary: true });
    this.playerRoom.delete(socket.id);
  }

  handleDisconnect(socket) {
    this.cancelQuickMatch(socket);
    const code = this.playerRoom.get(socket.id);
    if (!code) return;
    const room = this.rooms.get(code);
    if (room) room.handlePlayerGone(socket.id, { voluntary: false });
    this.playerRoom.delete(socket.id);
  }

  _onRoomFinished(code) {
    const room = this.rooms.get(code);
    if (room) {
      for (const p of room.players) this.playerRoom.delete(p.socketId);
      room.destroy();
    }
    this.rooms.delete(code);
  }
}

module.exports = RoomManager;
