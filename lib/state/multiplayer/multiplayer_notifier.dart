import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/constants/cities.dart';
import '../../core/network/socket_service.dart';
import '../../domain/entities/game_city.dart';
import '../../domain/entities/okey_models.dart';
import 'multiplayer_state.dart';

GameCity? _cityFromJson(dynamic raw) {
  if (raw == null) return null;
  return GameCity.fromJson(Map<String, dynamic>.from(raw as Map));
}

GameCity? _cityById(String? cityId) {
  if (cityId == null) return null;
  for (final city in kCities) {
    if (city.id == cityId) return city;
  }
  return null;
}

/// Sunucunun onerdigi el dizilimi: per gruplari + geriye kalan taslar.
class ArrangeResult {
  final List<List<int>> groups;
  final List<int> rest;
  const ArrangeResult(this.groups, this.rest);
}

List<int> _ids(dynamic raw) => (raw as List).map((e) => (e as num).toInt()).toList();

/// 101 Okey coklu oyunculu akisi. Sunucu (server/okey) tek otoritedir; bu
/// notifier sunucudan gelen durumu yansitir ve kullanici hamlelerini iletir.
class MultiplayerNotifier extends StateNotifier<MultiplayerState> {
  MultiplayerNotifier() : super(const MultiplayerState());

  io.Socket? _socket;
  bool _disposed = false;
  Timer? _peekTimer;
  Timer? _recoverTimer;
  Completer<ArrangeResult>? _arrangeCompleter;

  @override
  void dispose() {
    _disposed = true;
    _peekTimer?.cancel();
    _recoverTimer?.cancel();
    super.dispose();
  }

  void _setState(MultiplayerState Function() build) {
    if (_disposed) return;
    state = build();
  }

  Future<void> connect(String url) async {
    String? token;
    try {
      // Her baglantida taze token: eski token yuzunden "Kimlik dogrulanamadi"
      // hatasi olusmasin.
      token = await fb_auth.FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (_) {
      token = null;
    }

    final socket = SocketService().connect(url, token: token);
    if (identical(socket, _socket)) {
      if (state.stage == MpStage.disconnected) {
        _setState(() => state.copyWith(stage: socket.connected ? MpStage.menu : MpStage.connecting));
      }
      return;
    }

    _socket = socket;
    state = const MultiplayerState(stage: MpStage.connecting);
    _registerListeners(socket);
  }

  void _registerListeners(io.Socket socket) {
    socket.onConnect((_) {
      if (state.connectionLost) {
        // Masaya donus: sunucu ayni hesabi taniyip durumu (okey_state) yollar.
        // Sure icinde gelmezse (masa bitti / sure doldu) lobiye don.
        _recoverTimer?.cancel();
        _recoverTimer = Timer(const Duration(seconds: 8), () {
          if (state.connectionLost) {
            _setState(() => const MultiplayerState(
                  stage: MpStage.menu,
                  errorMessage: 'Masana dönemedin (süre doldu ya da oyun bitti).',
                ));
          }
        });
        return;
      }
      _setState(() => state.copyWith(stage: MpStage.menu, clearError: true));
    });

    void lost(String message) {
      if (state.stage == MpStage.playing && state.view != null) {
        _setState(() => state.copyWith(connectionLost: true));
        return;
      }
      _setState(() => MultiplayerState(stage: MpStage.disconnected, errorMessage: message));
    }

    socket.onDisconnect((_) => lost('Sunucu baglantisi koptu.'));
    socket.onConnectError((error) => lost('Sunucuya baglanilamadi: $error'));

    socket.on('searching', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _setState(() => state.copyWith(
            stage: MpStage.searchingCity,
            city: _cityById(map['cityId'] as String?),
            clearError: true,
          ));
    });

    socket.on('room_created', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _setState(() => state.copyWith(
            stage: MpStage.roomWaitingForOpponent,
            roomCode: map['code'] as String,
            city: _cityFromJson(map['city']),
            roomPlayers: const [],
            isHost: true,
            clearError: true,
          ));
    });

    socket.on('room_joined', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _setState(() => state.copyWith(
            stage: MpStage.roomWaitingForOpponent,
            isHost: false,
            roomCode: map['code'] as String,
            city: _cityFromJson(map['city']),
            clearError: true,
          ));
    });

    socket.on('room_players', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final names = (map['players'] as List)
          .map((p) => (Map<String, dynamic>.from(p as Map))['name'] as String)
          .toList();
      _setState(() => state.copyWith(roomPlayers: names));
    });

    socket.on('room_error', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _setState(() => state.copyWith(
            stage: MpStage.menu,
            errorMessage: (map['message'] as String?) ?? 'Bilinmeyen hata',
            clearRoomCode: true,
          ));
    });

    socket.on('match_found', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _setState(() => MultiplayerState(
            stage: MpStage.playing,
            city: _cityFromJson(map['city']),
            humans: (map['humans'] as List).map((e) => e == true).toList(),
          ));
    });

    socket.on('okey_state', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final view = OkeyView.fromJson(Map<String, dynamic>.from(map['view'] as Map));
      final dl = (map['deadline'] as num?)?.toInt();
      _setState(() => state.copyWith(
            stage: state.stage == MpStage.finished ? MpStage.finished : MpStage.playing,
            view: view,
            deadlineMs: dl,
            clearDeadline: dl == null,
            humans: (map['humans'] as List?)?.map((e) => e == true).toList(),
            clearPreview: true,
            connectionLost: false,
          ));
    });

    socket.on('okey_over', (data) {
      final over = OkeyOver.fromJson(Map<String, dynamic>.from(data as Map));
      _setState(() => state.copyWith(stage: MpStage.finished, over: over));
    });

    socket.on('okey_error', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _setState(() => state.copyWith(toast: (map['message'] as String?) ?? 'Hamle geçersiz.'));
    });

    socket.on('power_error', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _setState(() => state.copyWith(toast: (map['message'] as String?) ?? 'Güç kullanılamadı.'));
    });

    socket.on('power_used', (_) {});

    socket.on('okey_peek', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final t = OkeyTile.fromJson(Map<String, dynamic>.from(map['tile'] as Map));
      _setState(() => state.copyWith(peekTile: t));
      _peekTimer?.cancel();
      _peekTimer = Timer(const Duration(seconds: 4), () => _setState(() => state.copyWith(clearPeek: true)));
    });

    socket.on('okey_arrange_result', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final groups = (map['groups'] as List).map(_ids).toList();
      _arrangeCompleter?.complete(ArrangeResult(groups, _ids(map['rest'])));
      _arrangeCompleter = null;
    });

    socket.on('okey_preview_result', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _setState(() => state.copyWith(
            preview: MeldPreview(
              values: _ids(map['values']),
              types: (map['types'] as List).map((e) => e as String?).toList(),
              total: (map['total'] as num).toInt(),
              pairs: (map['pairs'] as num).toInt(),
            ),
          ));
    });

    socket.on('room_invite', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _setState(() => state.copyWith(
            incomingInvite: GameInvite(
              fromUsername: (map['fromUsername'] as String?) ?? 'Bir arkadaşın',
              code: map['code'] as String,
              city: _cityFromJson(map['city']),
            ),
          ));
    });
  }

  // ------------------------------------------------------------- lobi
  void joinCityQueue(String cityId, String name) {
    if (state.stage != MpStage.menu) return;
    _socket?.emit('join_city_queue', {'cityId': cityId, 'name': name});
  }

  void cancelCityQueue() {
    _socket?.emit('cancel_city_queue');
    _setState(() => state.copyWith(stage: MpStage.menu, clearError: true, clearCity: true));
  }

  void createRoom(String name, {required String cityId}) {
    if (state.stage != MpStage.menu) return;
    _socket?.emit('create_room', {'name': name, 'cityId': cityId});
  }

  void joinRoom(String code, String name) {
    if (state.stage != MpStage.menu) return;
    _socket?.emit('join_room', {'code': code, 'name': name});
  }

  /// Oda sahibi: oyunu baslat (bos koltuklara bot oturur).
  void startRoom() => _socket?.emit('start_room');

  void inviteFriend(String targetUid) {
    if (state.stage != MpStage.roomWaitingForOpponent) return;
    _socket?.emit('invite_friend', {'targetUid': targetUid});
  }

  void acceptInvite(String username) {
    final invite = state.incomingInvite;
    if (invite == null) return;
    _setState(() => state.copyWith(clearIncomingInvite: true));
    joinRoom(invite.code, username);
  }

  void declineInvite() => _setState(() => state.copyWith(clearIncomingInvite: true));

  // ------------------------------------------------------------ oyun hamleleri
  bool get _canAct => state.stage == MpStage.playing && (state.view?.isMyTurn ?? false);

  void drawFromDeck() {
    if (!_canAct) return;
    _socket?.emit('okey_draw', {'source': 'deck'});
  }

  void drawFromDiscard() {
    if (!_canAct) return;
    _socket?.emit('okey_draw', {'source': 'discard'});
  }

  void layMelds(List<List<int>> groups) {
    if (!_canAct) return;
    _socket?.emit('okey_lay', {'groups': groups});
  }

  void addToMeld(int tileId, int owner, int meld) {
    if (!_canAct) return;
    _socket?.emit('okey_add', {'tileId': tileId, 'owner': owner, 'meld': meld});
  }

  void discard(int tileId) {
    if (!_canAct) return;
    _socket?.emit('okey_discard', {'tileId': tileId});
  }

  void usePower(String power) {
    if (state.stage != MpStage.playing) return;
    _socket?.emit('use_power', {'power': power});
  }

  void requestPreview(List<List<int>> groups) {
    if (state.stage != MpStage.playing) return;
    _socket?.emit('okey_preview', {'groups': groups});
  }

  Future<ArrangeResult?> requestArrange() async {
    if (state.stage != MpStage.playing) return null;
    _arrangeCompleter = Completer<ArrangeResult>();
    _socket?.emit('okey_arrange');
    try {
      return await _arrangeCompleter!.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      _arrangeCompleter = null;
      return null;
    }
  }

  void clearToast() => _setState(() => state.copyWith(clearToast: true));

  // ----------------------------------------------------------------- cikis
  /// Masadan kalkma: aktif oyunda yerine bot gecer, giris ucreti kaybedilir.
  void leaveTable() {
    _socket?.emit('leave_room');
    _setState(() => state.copyWith(stage: MpStage.menu));
  }

  void backToMenuAfterFinish() {
    _socket?.emit('leave_room');
    _setState(() => state.copyWith(stage: MpStage.menu, clearOver: true));
  }

  void disconnectAndExit() {
    SocketService().disconnect();
    _socket = null;
    _setState(() => const MultiplayerState(stage: MpStage.disconnected));
  }
}

final multiplayerProvider = StateNotifierProvider<MultiplayerNotifier, MultiplayerState>((ref) {
  return MultiplayerNotifier();
});
