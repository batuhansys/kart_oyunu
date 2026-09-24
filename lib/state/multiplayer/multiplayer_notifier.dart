import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/network/socket_service.dart';
import '../../domain/entities/mp_history_entry.dart';
import '../../domain/entities/player_choice.dart';
import '../../domain/entities/playing_card.dart';
import 'multiplayer_state.dart';

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
  void connect(String url) {
    final socket = SocketService().connect(url);
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

    socket.on('searching', (_) {
      _setState(() => state.copyWith(stage: MpStage.searchingQuickMatch, clearError: true));
    });

    socket.on('room_created', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _setState(() => state.copyWith(
            stage: MpStage.roomWaitingForOpponent,
            roomCode: map['code'] as String,
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
            opponentHasChosen: false,
          ));
    });

    socket.on('opponent_choice_made', (_) {
      _setState(() => state.copyWith(opponentHasChosen: true));
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
            youWon: map['youWon'] as bool?,
            yourScore: map['yourScore'] as int,
            opponentScore: map['opponentScore'] as int,
            finishReason: map['reason'] as String?,
          ));
    });
  }

  bool get canSubmitChoice => state.stage == MpStage.playing && state.yourChoice == null;

  void quickMatch(String name) {
    if (state.stage != MpStage.menu) return;
    _socket?.emit('quick_match', {'name': name});
  }

  void cancelQuickMatch() {
    _socket?.emit('cancel_quick_match');
    _setState(() => state.copyWith(stage: MpStage.menu, clearError: true));
  }

  void createRoom(String name) {
    if (state.stage != MpStage.menu) return;
    _socket?.emit('create_room', {'name': name});
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
  void leaveTable() {
    _socket?.emit('leave_room');
    _setState(() => const MultiplayerState(stage: MpStage.menu));
  }

  void backToMenuAfterFinish() {
    _setState(() => const MultiplayerState(stage: MpStage.menu));
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
