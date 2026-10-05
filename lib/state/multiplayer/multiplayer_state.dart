import '../../domain/entities/game_city.dart';
import '../../domain/entities/okey_models.dart';

/// Coklu oyunculu akisin hangi asamada oldugunu belirtir.
enum MpStage {
  /// Soket henuz baglanmadi / lobiye hic girilmedi.
  disconnected,

  /// Sunucuya baglaniliyor.
  connecting,

  /// Baglandi, ana lobi menusu gosteriliyor (sehirler / arkadasinla oyna).
  menu,

  /// Secilen sehrin kuyrugunda oyuncu bekleniyor (sure dolunca botlar dolar).
  searchingCity,

  /// Ozel oda kuruldu/katilindi; oda sahibi "Baslat"a basana kadar bekleniyor.
  roomWaitingForOpponent,

  /// Oyun suruyor.
  playing,

  /// Oyun bitti (siralama gosteriliyor).
  finished,
}

/// Bir arkadasin gonderdigi, henuz cevaplanmamis oda daveti.
class GameInvite {
  final String fromUsername;
  final String code;
  final GameCity? city;

  const GameInvite({required this.fromUsername, required this.code, this.city});
}

/// Raftaki per adaylarinin sunucu onizlemesi (gecerlilik + puan).
class MeldPreview {
  final List<int> values; // -1: gecersiz
  final List<String?> types;
  final int total;
  final int pairs;
  const MeldPreview({required this.values, required this.types, required this.total, required this.pairs});
}

class MultiplayerState {
  final MpStage stage;
  final String? errorMessage;

  // Lobi
  final String? roomCode;
  final List<String> roomPlayers;
  final bool isHost;
  final GameCity? city;

  // Oyun
  final OkeyView? view;
  final int? deadlineMs; // sunucu epoch ms; tur/ara sayaci icin
  final List<bool> humans;
  final OkeyOver? over;

  /// Gecici (SnackBar) hata/bilgi mesaji: sunucu reddettiginde gelir.
  final String? toast;

  /// KAHIN ile gorulen deste ustu tasi (bir sure sonra gizlenir).
  final OkeyTile? peekTile;

  final MeldPreview? preview;

  /// Su an cevap bekleyen, bir arkadastan gelen oda daveti (varsa).
  final GameInvite? incomingInvite;

  /// Oyun sirasinda baglanti koptu; sunucu masayi bizim icin tutuyor (bot oynuyor).
  final bool connectionLost;

  const MultiplayerState({
    this.stage = MpStage.disconnected,
    this.errorMessage,
    this.roomCode,
    this.roomPlayers = const [],
    this.isHost = false,
    this.city,
    this.view,
    this.deadlineMs,
    this.humans = const [],
    this.over,
    this.toast,
    this.peekTile,
    this.preview,
    this.incomingInvite,
    this.connectionLost = false,
  });

  MultiplayerState copyWith({
    MpStage? stage,
    String? errorMessage,
    bool clearError = false,
    String? roomCode,
    bool clearRoomCode = false,
    List<String>? roomPlayers,
    bool? isHost,
    GameCity? city,
    bool clearCity = false,
    OkeyView? view,
    int? deadlineMs,
    bool clearDeadline = false,
    List<bool>? humans,
    OkeyOver? over,
    bool clearOver = false,
    String? toast,
    bool clearToast = false,
    OkeyTile? peekTile,
    bool clearPeek = false,
    MeldPreview? preview,
    bool clearPreview = false,
    GameInvite? incomingInvite,
    bool clearIncomingInvite = false,
    bool? connectionLost,
  }) {
    return MultiplayerState(
      stage: stage ?? this.stage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      roomCode: clearRoomCode ? null : (roomCode ?? this.roomCode),
      roomPlayers: roomPlayers ?? this.roomPlayers,
      isHost: isHost ?? this.isHost,
      city: clearCity ? null : (city ?? this.city),
      view: view ?? this.view,
      deadlineMs: clearDeadline ? null : (deadlineMs ?? this.deadlineMs),
      humans: humans ?? this.humans,
      over: clearOver ? null : (over ?? this.over),
      toast: clearToast ? null : (toast ?? this.toast),
      peekTile: clearPeek ? null : (peekTile ?? this.peekTile),
      preview: clearPreview ? null : (preview ?? this.preview),
      incomingInvite: clearIncomingInvite ? null : (incomingInvite ?? this.incomingInvite),
      connectionLost: connectionLost ?? this.connectionLost,
    );
  }
}
