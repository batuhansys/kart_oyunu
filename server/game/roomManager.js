const OkeyRoom = require('../okey/room');
const { getCity } = require('./cities');

// Kod okurken karistirilabilecek karakterler (0/O, 1/I/L) haric tutuldu.
const CODE_CHARSET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 5;

// Sehir kuyrugunda ilk oyuncu girdikten sonra bu kadar beklenir; sure
// dolunca (veya 4 insan toplaninca) oyun baslar, bos koltuklara bot oturur.
const QUEUE_WAIT_MS = 7000;

/**
 * Aktif odalari, oda-kodu -> oda eslesmesini, oyuncu soketi -> oda
 * eslesmesini ve sehir bazli bekleme kuyruklarini yonetir. server.js buradaki
 * metodlari socket olaylarina bagli cagirir.
 */
class RoomManager {
  constructor(io) {
    this.io = io;
    this.rooms = new Map(); // code -> OkeyRoom
    this.playerRoom = new Map(); // socketId -> code
    this.cityQueues = new Map(); // cityId -> { players: [{socketId,name,uid}], timer }
    this.uidSocket = new Map(); // uid -> socketId (sadece kimligi dogrulanmis baglantilar)
    this.uidRoom = new Map(); // uid -> oda kodu (ayni hesap iki masada olamaz)
  }

  registerSocket(socket) {
    const uid = socket.data.uid;
    if (!uid) return;
    this.uidSocket.set(uid, socket.id);
    // Oyun sirasinda kopan oyuncu geri geldiyse masasina dondur.
    const code = this.uidRoom.get(uid);
    const room = code && this.rooms.get(code);
    if (room && room.reattach(socket.id, uid)) this.playerRoom.set(socket.id, code);
  }

  unregisterSocket(socket) {
    if (socket.data.uid && this.uidSocket.get(socket.data.uid) === socket.id) {
      this.uidSocket.delete(socket.data.uid);
    }
  }

  _generateCode() {
    let code;
    do {
      code = '';
      for (let i = 0; i < CODE_LENGTH; i++) code += CODE_CHARSET[Math.floor(Math.random() * CODE_CHARSET.length)];
    } while (this.rooms.has(code));
    return code;
  }

  _isAlreadyPlaying(socket) {
    const uid = socket.data.uid;
    if (this.playerRoom.has(socket.id) || (uid && this.uidRoom.has(uid))) {
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

  _newRoom(mode, city) {
    const code = this._generateCode();
    const room = new OkeyRoom({ id: code, mode, io: this.io, city, onFinished: (id) => this._onRoomFinished(id) });
    this.rooms.set(code, room);
    return { code, room };
  }

  // ---------------------------------------------------------- ozel (arkadas) oda
  createPrivateRoom(socket, name, cityId) {
    if (this._isAlreadyPlaying(socket)) return;
    let city = null;
    if (cityId) {
      city = getCity(cityId);
      if (!city) { socket.emit('room_error', { message: 'Geçersiz şehir.' }); return; }
    }
    const { code, room } = this._newRoom('private', city);
    room.addPlayer(socket.id, name, socket.data.uid);
    this.playerRoom.set(socket.id, code);
    if (socket.data.uid) this.uidRoom.set(socket.data.uid, code);
    socket.emit('room_created', { code, city });
  }

  joinPrivateRoom(socket, rawCode, name) {
    if (this._isAlreadyPlaying(socket)) return;
    const code = (rawCode || '').toString().trim().toUpperCase();
    const room = this.rooms.get(code);
    if (!room) { socket.emit('room_error', { message: 'Oda bulunamadi. Kodu kontrol edin.' }); return; }
    if (room.status !== 'waiting' || room.isFull) { socket.emit('room_error', { message: 'Bu oda artik uygun degil.' }); return; }
    room.addPlayer(socket.id, name, socket.data.uid);
    this.playerRoom.set(socket.id, code);
    if (socket.data.uid) this.uidRoom.set(socket.data.uid, code);
    socket.emit('room_joined', { code, city: room.city });
  }

  /** Oda sahibi "Baslat"a basinca (bos koltuklar botla dolar). */
  startRoom(socket) {
    const code = this.playerRoom.get(socket.id);
    const room = code && this.rooms.get(code);
    if (!room || room.status !== 'waiting') return;
    if (room.indexOfSocket(socket.id) !== 0) {
      socket.emit('room_error', { message: 'Oyunu sadece oda sahibi başlatabilir.' });
      return;
    }
    this._startRoom(room, code);
  }

  // ---------------------------------------------------------- sehir kuyrugu
  joinCityQueue(socket, cityId, name) {
    if (this._isAlreadyPlaying(socket)) return;
    const city = getCity(cityId);
    if (!city) { socket.emit('room_error', { message: 'Geçersiz şehir.' }); return; }

    let q = this.cityQueues.get(cityId);
    if (!q) { q = { players: [], timer: null }; this.cityQueues.set(cityId, q); }
    if (q.players.some((p) => p.socketId === socket.id)) return;
    q.players.push({ socketId: socket.id, name, uid: socket.data.uid });
    socket.emit('searching', { cityId });

    if (q.players.length >= 4) {
      this._flushQueue(cityId);
    } else if (!q.timer) {
      q.timer = setTimeout(() => this._flushQueue(cityId), QUEUE_WAIT_MS);
    }
  }

  _flushQueue(cityId) {
    const q = this.cityQueues.get(cityId);
    if (!q) return;
    clearTimeout(q.timer);
    q.timer = null;
    const city = getCity(cityId);
    const players = q.players.filter((p) => this.io.sockets.sockets.get(p.socketId));
    q.players = [];
    if (players.length === 0) return;

    const { code, room } = this._newRoom('city', city);
    for (const p of players) {
      room.addPlayer(p.socketId, p.name, p.uid);
      this.playerRoom.set(p.socketId, code);
      if (p.uid) this.uidRoom.set(p.uid, code);
    }
    this._startRoom(room, code);
  }

  cancelCityQueue(socket) {
    for (const [cityId, q] of this.cityQueues) {
      const filtered = q.players.filter((p) => p.socketId !== socket.id);
      if (filtered.length !== q.players.length) {
        q.players = filtered;
        if (filtered.length === 0) { clearTimeout(q.timer); q.timer = null; }
        this.cityQueues.set(cityId, q);
      }
    }
  }

  // ---------------------------------------------------------------- davet
  inviteFriend(socket, targetUid) {
    const code = this.playerRoom.get(socket.id);
    if (!code) return;
    const room = this.rooms.get(code);
    if (!room || room.status !== 'waiting') return;

    const targetSocketId = this.uidSocket.get(targetUid);
    const targetSocket = targetSocketId ? this.io.sockets.sockets.get(targetSocketId) : null;
    if (!targetSocket) {
      socket.emit('room_error', { message: 'Arkadaşın şu an çevrimiçi değil.' });
      return;
    }
    const inviter = room.players.find((p) => p.socketId === socket.id);
    targetSocket.emit('room_invite', {
      fromUsername: inviter ? inviter.name : 'Bir arkadaşın',
      code,
      city: room.city,
    });
  }

  // ------------------------------------------------------- oyun ici olaylar
  _room(socket) {
    const code = this.playerRoom.get(socket.id);
    return code ? this.rooms.get(code) : null;
  }

  action(socket, action) {
    const room = this._room(socket);
    if (room) room.handleAction(socket.id, action);
  }

  arrange(socket) {
    const room = this._room(socket);
    if (room) room.arrange(socket.id);
  }

  preview(socket, groups) {
    const room = this._room(socket);
    if (room) room.preview(socket.id, groups);
  }

  usePower(socket, power) {
    const room = this._room(socket);
    if (room) {
      room.usePower(socket.id, power).catch((err) => {
        // eslint-disable-next-line no-console
        console.error('[power] usePower failed:', err);
      });
    }
  }

  /** voluntary=true: oyuncu bilerek ayrildi; false: baglanti koptu (geri donebilir). */
  leaveRoom(socket, voluntary = true) {
    const code = this.playerRoom.get(socket.id);
    if (!code) return;
    const room = this.rooms.get(code);
    if (room) room.handlePlayerGone(socket.id, { voluntary });
    this.playerRoom.delete(socket.id);
    const uid = socket.data.uid;
    // Bilerek ayrilan hesap serbest kalir; kopan hesap oda bitene kadar bagli kalir.
    if (uid && (voluntary || !room || room.status !== 'active')) {
      if (this.uidRoom.get(uid) === code) this.uidRoom.delete(uid);
    }
  }

  handleDisconnect(socket) {
    this.unregisterSocket(socket);
    this.cancelCityQueue(socket);
    this.leaveRoom(socket, false);
  }

  _onRoomFinished(code) {
    const room = this.rooms.get(code);
    if (room) {
      for (const s of room.seats) {
        if (s.socketId) this.playerRoom.delete(s.socketId);
        if (s.uid && this.uidRoom.get(s.uid) === code) this.uidRoom.delete(s.uid);
      }
      room.destroy();
    }
    this.rooms.delete(code);
  }
}

module.exports = RoomManager;
