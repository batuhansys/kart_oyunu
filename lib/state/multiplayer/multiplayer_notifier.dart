import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/constants/cities.dart';
import '../../core/network/socket_service.dart';
import '../../domain/entities/game_city.dart';
import '../../domain/entities/mp_history_entry.dart';
import '../../domain/entities/player_choice.dart';
import '../../domain/entities/playing_card.dart';
import 'multiplayer_state.dart';

/// Sunucudan gelen `city` haritasini (varsa) GameCity'e cevirir. Server
/// bunu bazen null gonderir (sehirsiz/eski private room akisi).
GameCity? _cityFromJson(dynamic raw) {
  if (raw == null) return null;
  return GameCity.fromJson(Map<String, dynamic>.from(raw as Map));
}

/// Client'ta gosterim icin: sadece bir cityId geldiginde (orn.
/// 'searching' olayi) kendi bildigimiz listeden şehri bulur. Sunucu
/// giris ucretini her zaman KENDI listesinden dogrular; burasi salt
/// gorsel amaclidir.
GameCity? _cityById(String? cityId) {
  if (cityId == null) return null;
  for (final city in kCities) {
    if (city.id == cityId) return city;
  }
  return null;
}

/// `as bool` / `as bool?`, Flutter web'de socket.io-client'in JS-interop
/// koprusunden gelen ham JS boolean degerlerinde DDC'nin sikca calisan
/// tip kontrolunde (_asBool) beklenmedik sekilde firlatabiliyor (int/String
/// castlarinda bu sorun yok). `== true` karsilastirmasi bu RTI kontrolunu
/// gerektirmedigi icin guvenli calisir.
bool _asBool(dynamic v) => v == true;
bool? _asBoolOrNull(dynamic v) => v == null ? null : v == true;

/// Coklu oyunculu (multiplayer) akisin tum state machine'ini yonetir.
/// Sunucu (server/) puanlama ve zaman asimi konusunda tek otoritedir;
/// bu notifier sadece sunucudan gelen olaylari state'e yansitir ve
/// kullanicinin niyetlerini (eslesme ara, secim yap, masadan kalk vb.)
/// sunucuya iletir. Boylece istemci tarafinda hile (skor degistirme)
/// mumkun degildir.
///
/// lib/state/game/game_notifier.dart'taki tek-oyunculu akisin aksine
/// burada "kim once secer" kavrami yoktur: iki gercek oyuncu ayni anda,
/// birbirinin secimini gormeden karar verir (bkz. server/game/room.js).
class MultiplayerNotifier extends StateNotifier<MultiplayerState> {
  MultiplayerNotifier() : super(const MultiplayerState());

  io.Socket? _socket;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _setState(MultiplayerState Function() build) {
    if (_disposed) return;
    state = build();
  }

  /// Sunucuya baglanir. Zaten ayni sunucuya bagliysa yeniden baglanmaz.
  /// Once (varsa) giris yapmis kullanicinin guncel Firebase ID token'ini
  /// alir — sunucu bunu dogrulayip socket.data.uid'i set eder, sehirli
  /// (giris ucretli) maclar bu olmadan oynanamaz (bkz. server/server.js).
  Future<void> connect(String url) async {
    String? token;
    try {
      token = await fb_auth.FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      token = null; // misafir olarak devam; sehirli maclar reddedilir.
    }

    final socket = SocketService().connect(url, token: token);
    if (identical(socket, _socket)) {
      if (state.stage == MpStage.disconnected) {
        _setState(() => state.copyWith(
              stage: socket.connected ? MpStage.menu : MpStage.connecting,
            ));
      }
      return;
    }

    _socket = socket;
    state = const MultiplayerState(stage: MpStage.connecting);
    _registerListeners(socket);
  }

  void _registerListeners(io.Socket socket) {
    socket.onConnect((_) {
      _setState(() => state.copyWith(stage: MpStage.menu, clearError: true));
    });

    socket.onDisconnect((_) {
      _setState(() => const MultiplayerState(
            stage: MpStage.disconnected,
            errorMessage: 'Sunucu baglantisi koptu.',
          ));
    });

    socket.onConnectError((error) {
      _setState(() => MultiplayerState(
            stage: MpStage.disconnected,
            errorMessage: 'Sunucuya baglanilamadi: $error',
          ));
    });

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
            clearError: true,
          ));
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
            myIndex: map['myIndex'] as int,
            opponentName: (map['opponentName'] as String?) ?? 'Rakip',
            city: _cityFromJson(map['city']),
          ));
    });

    socket.on('round_start', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _setState(() => state.copyWith(
            stage: MpStage.playing,
            roundId: map['roundId'] as int,
            yourCard: PlayingCard.fromJson(Map<String, dynamic>.from(map['yourCard'] as Map)),
            clearOpponentCard: true,
            clearYourChoice: true,
            clearOpponentChoice: true,
            isYourTurn: _asBool(map['isYourTurn']),
          ));
    });

    // Oncelikli oyuncu secimini yapinca (veya suresi dolunca) gelir:
    // rakibin secim RENGI acilir (karti degil) ve simdi bizim siramiz
    // baslar. bkz. server/game/room.js _advanceToReactivePhase.
    socket.on('priority_revealed', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final revealedChoice = playerChoiceFromWire(map['choice'] as String);
      _setState(() => state.copyWith(opponentChoice: revealedChoice, isYourTurn: true));
    });

    socket.on('round_result', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final yourCard = PlayingCard.fromJson(Map<String, dynamic>.from(map['yourCard'] as Map));
      final opponentCard =
          PlayingCard.fromJson(Map<String, dynamic>.from(map['opponentCard'] as Map));
      final yourChoice = playerChoiceFromWire(map['yourChoice'] as String);
      final opponentChoice = playerChoiceFromWire(map['opponentChoice'] as String);

      final newHistory = <MpHistoryEntry>[
        MpHistoryEntry(
          yourCard: yourCard,
          opponentCard: opponentCard,
          yourChoice: yourChoice,
          opponentChoice: opponentChoice,
          yourDelta: map['yourDelta'] as int,
          opponentDelta: map['opponentDelta'] as int,
        ),
        ...state.history,
      ];
      if (newHistory.length > 10) newHistory.removeLast();

      _setState(() => state.copyWith(
            yourCard: yourCard,
            opponentCard: opponentCard,
            yourChoice: yourChoice,
            opponentChoice: opponentChoice,
            yourScore: map['yourScore'] as int,
            opponentScore: map['opponentScore'] as int,
            yourConsecutivePasses:
                yourChoice == PlayerChoice.pass ? state.yourConsecutivePasses + 1 : 0,
            history: newHistory,
          ));
    });

    socket.on('game_over', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _setState(() => state.copyWith(
            stage: MpStage.finished,
            youWon: _asBoolOrNull(map['youWon']),
            yourScore: map['yourScore'] as int,
            opponentScore: map['opponentScore'] as int,
            finishReason: map['reason'] as String?,
            rematchStatus: RematchStatus.none,
          ));
    });

    socket.on('rematch_pending', (_) {
      _setState(() => state.copyWith(rematchStatus: RematchStatus.requestedByMe));
    });

    socket.on('rematch_requested', (_) {
      _setState(() => state.copyWith(rematchStatus: RematchStatus.requestedByOpponent));
    });

    socket.on('rematch_accepted', (_) {
      _setState(() => MultiplayerState(
            stage: MpStage.playing,
            myIndex: state.myIndex,
            opponentName: state.opponentName,
          ));
    });
  }

  bool get canSubmitChoice =>
      state.stage == MpStage.playing &&
      state.yourCard != null &&
      state.yourChoice == null &&
      state.isYourTurn;

  /// Bir sehir secilince cagrilir: sunucu o sehri secen baska (bagli)
  /// birini bulursa hemen eslestirir, yoksa kuyruga ekler (bkz.
  /// server/game/roomManager.js joinCityQueue).
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

  void submitChoice(PlayerChoice choice) {
    if (!canSubmitChoice) return;
    if (choice == PlayerChoice.pass && !state.canPass) return;
    _socket?.emit('submit_choice', {'choice': choice.wireValue});
    _setState(() => state.copyWith(yourChoice: choice));
  }

  /// Masadan kalkma: aktif bir es varsa rakip otomatik kazanir (bkz.
  /// server Room.handlePlayerGone), oda kurulmus ama rakip gelmemisse
  /// oda iptal edilir.
  ///
  /// Sadece `stage`'i degistiriyoruz (kart/skor gibi alanlari SIFIRLAMIYORUZ):
  /// GoRouter'in pop gecis animasyonu (~320ms) boyunca bu ekran hala
  /// mounted durumda ve provider'i dinlemeye devam ediyor. Eger burada
  /// state'i tamamen bos bir MultiplayerState() ile degistirseydik, o
  /// gecis sirasinda oyun masasi bir anlik "Sen: 0, Rakip: 0" ve bos
  /// kartlarla yeniden cizilip yeni bir el basliyormus gibi gorunuyordu
  /// (bkz. kullanici raporu: "Lobiye dön dediğimde tekrar oyuna dahil
  /// ediyor"). Bir sonraki gercek eslesme (match_found/room_created)
  /// zaten tamamen taze bir MultiplayerState olusturuyor, o yuzden
  /// burada eski alanlarin bir sure ekranda asili kalmasinin bir
  /// zarari yok.
  void leaveTable() {
    _socket?.emit('leave_room');
    _setState(() => state.copyWith(stage: MpStage.menu));
  }

  void backToMenuAfterFinish() {
    _socket?.emit('leave_room');
    _setState(() => state.copyWith(stage: MpStage.menu));
  }

  /// Oyun sonu ekraninda "Tekrar Meydan Oku"ya basildiginda cagrilir.
  void requestRematch() {
    if (state.stage != MpStage.finished) return;
    _socket?.emit('request_rematch');
  }

  /// Rakibin meydan okumasini "Kabul Et" ile onaylar.
  void acceptRematch() {
    if (state.stage != MpStage.finished) return;
    _socket?.emit('accept_rematch');
  }

  void disconnectAndExit() {
    SocketService().disconnect();
    _socket = null;
    _setState(() => const MultiplayerState(stage: MpStage.disconnected));
  }
}

final multiplayerProvider =
    StateNotifierProvider<MultiplayerNotifier, MultiplayerState>((ref) {
  return MultiplayerNotifier();
});
