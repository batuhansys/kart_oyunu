const Room = require('./room');
const { getCity } = require('./cities');

// Kod okurken karistirilabilecek karakterler (0/O, 1/I/L) haric tutuldu.
const CODE_CHARSET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 5;

/**
 * Tum aktif odalari, oda-kodu -> oda esleşmesini, oyuncu socket'i -> oda
 * esleşmesini ve sehir bazli "online eslesme" bekleme kuyruklarini
 * yonetir. server.js buradaki metodlari socket olaylarina bagli olarak
 * cagirir; bu sinif socket.io olay isimlerinden habersizdir (sadece
 * io.to(...).emit kullanir).
 */
class RoomManager {
  constructor(io) {
    this.io = io;
    this.rooms = new Map(); // code -> Room
    this.playerRoom = new Map(); // socketId -> code
    this.cityQueues = new Map(); // cityId -> [{ socketId, name, uid }]
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

  _startRoom(room, code) {
    room.start().catch((err) => {
      // eslint-disable-next-line no-console
      console.error(`[room ${code}] start() failed:`, err);
    });
  }

  createPrivateRoom(socket, name, cityId) {
    if (this._isAlreadyPlaying(socket)) return;

    let city = null;
    if (cityId) {
      city = getCity(cityId);
      if (!city) {
        socket.emit('room_error', { message: 'Geçersiz şehir.' });
        return;
      }
    }

    const code = this._generateCode();
    const room = new Room({
      id: code,
      mode: 'private',
      io: this.io,
      city,
      onFinished: (id) => this._onRoomFinished(id),
    });
    room.addPlayer(socket.id, name, socket.data.uid);
    this.rooms.set(code, room);
    this.playerRoom.set(socket.id, code);
    socket.emit('room_created', { code, city });
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

    room.addPlayer(socket.id, name, socket.data.uid);
    this.playerRoom.set(socket.id, code);
    this._startRoom(room, code);
  }

  /// Kullanici bir sehir secince cagrilir: o sehre girmeye calisan baska
  /// (hala bagli) biri kuyrukta varsa hemen eslestirir, yoksa kuyruga
  /// ekler. Sadece AYNI sehri secenler birbiriyle eslesir.
  joinCityQueue(socket, cityId, name) {
    if (this._isAlreadyPlaying(socket)) return;

    const city = getCity(cityId);
    if (!city) {
      socket.emit('room_error', { message: 'Geçersiz şehir.' });
      return;
    }

    const queue = this.cityQueues.get(cityId) || [];

    while (queue.length > 0) {
      const waiting = queue.shift();
      if (waiting.socketId === socket.id) continue; // ayni oyuncu iki kez tiklamis olabilir
      const waitingSocket = this.io.sockets.sockets.get(waiting.socketId);
      if (!waitingSocket) continue; // kopmus, atla

      const code = this._generateCode();
      const room = new Room({
        id: code,
        mode: 'city',
        io: this.io,
        city,
        onFinished: (id) => this._onRoomFinished(id),
      });
      room.addPlayer(waiting.socketId, waiting.name, waiting.uid);
      room.addPlayer(socket.id, name, socket.data.uid);
      this.rooms.set(code, room);
      this.playerRoom.set(waiting.socketId, code);
      this.playerRoom.set(socket.id, code);
      this.cityQueues.set(cityId, queue);
      this._startRoom(room, code);
      return;
    }

    queue.push({ socketId: socket.id, name, uid: socket.data.uid });
    this.cityQueues.set(cityId, queue);
    socket.emit('searching', { cityId });
  }

  cancelCityQueue(socket) {
    for (const [cityId, queue] of this.cityQueues) {
      const filtered = queue.filter((q) => q.socketId !== socket.id);
      if (filtered.length !== queue.length) this.cityQueues.set(cityId, filtered);
    }
  }

  submitChoice(socket, choice) {
    const code = this.playerRoom.get(socket.id);
    if (!code) return;
    const room = this.rooms.get(code);
    if (!room) return;
    room.submitChoice(socket.id, choice);
  }

  requestRematch(socket) {
    const code = this.playerRoom.get(socket.id);
    if (!code) return;
    const room = this.rooms.get(code);
    if (room) room.requestRematch(socket.id);
  }

  acceptRematch(socket) {
    const code = this.playerRoom.get(socket.id);
    if (!code) return;
    const room = this.rooms.get(code);
    if (room) room.acceptRematch(socket.id);
  }

  leaveRoom(socket) {
    const code = this.playerRoom.get(socket.id);
    if (!code) return;
    const room = this.rooms.get(code);
    if (room) room.handlePlayerGone(socket.id, { voluntary: true });
    this.playerRoom.delete(socket.id);
  }

  handleDisconnect(socket) {
    this.cancelCityQueue(socket);
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
