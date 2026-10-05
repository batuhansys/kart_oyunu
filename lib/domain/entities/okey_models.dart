// Sunucudan (server/okey/game.js viewFor) gelen 101 Okey durum modelleri.

class OkeyTile {
  final int id;
  final int color; // 0 sari, 1 mavi, 2 siyah, 3 kirmizi; sahte okeyde -1
  final int number; // 1..13; sahte okeyde 0
  final bool fake;
  final bool joker; // gercek okey (her tasin yerine gecer)

  const OkeyTile({
    required this.id,
    required this.color,
    required this.number,
    this.fake = false,
    this.joker = false,
  });

  factory OkeyTile.fromJson(Map<String, dynamic> j) => OkeyTile(
        id: (j['id'] as num).toInt(),
        color: (j['c'] as num).toInt(),
        number: (j['n'] as num).toInt(),
        fake: j['f'] == 1,
        joker: j['j'] == 1,
      );

  @override
  bool operator ==(Object other) => other is OkeyTile && other.id == id;

  @override
  int get hashCode => id;
}

/// Perdeki bir tas ve temsil ettigi yuz (joker icin).
class MeldTile {
  final OkeyTile tile;
  final int asColor;
  final int asNumber;
  const MeldTile(this.tile, this.asColor, this.asNumber);
}

class OkeyMeld {
  final String type; // 'run' | 'group' | 'pair'
  final List<MeldTile> tiles;
  const OkeyMeld(this.type, this.tiles);

  factory OkeyMeld.fromJson(Map<String, dynamic> j) {
    final tiles = (j['tiles'] as List).map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final as = Map<String, dynamic>.from(m['as'] as Map);
      return MeldTile(OkeyTile.fromJson(m), (as['c'] as num).toInt(), (as['n'] as num).toInt());
    }).toList();
    return OkeyMeld(j['type'] as String, tiles);
  }
}

class OkeySeat {
  final int seat;
  final String name;
  final int handCount;
  final bool opened;
  final String? mode; // 'melds' | 'pairs'
  final int total;
  final int roundScore;
  final String? powerUsed;
  final OkeyTile? discardTop;
  final int discardCount;
  final List<OkeyMeld> melds;

  const OkeySeat({
    required this.seat,
    required this.name,
    required this.handCount,
    required this.opened,
    required this.mode,
    required this.total,
    required this.roundScore,
    required this.powerUsed,
    required this.discardTop,
    required this.discardCount,
    required this.melds,
  });

  factory OkeySeat.fromJson(Map<String, dynamic> j) => OkeySeat(
        seat: (j['seat'] as num).toInt(),
        name: j['name'] as String,
        handCount: (j['handCount'] as num).toInt(),
        opened: j['opened'] == true,
        mode: j['mode'] as String?,
        total: (j['total'] as num).toInt(),
        roundScore: (j['roundScore'] as num).toInt(),
        powerUsed: j['powerUsed'] as String?,
        discardTop: j['discardTop'] == null
            ? null
            : OkeyTile.fromJson(Map<String, dynamic>.from(j['discardTop'] as Map)),
        discardCount: (j['discardCount'] as num).toInt(),
        melds: (j['melds'] as List)
            .map((m) => OkeyMeld.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
      );
}

class RoundResult {
  final int? winner;
  final bool okeyFinish;
  final int multiplier;
  final List<int> scores;
  const RoundResult({required this.winner, required this.okeyFinish, required this.multiplier, required this.scores});

  factory RoundResult.fromJson(Map<String, dynamic> j) => RoundResult(
        winner: (j['winner'] as num?)?.toInt(),
        okeyFinish: j['okeyFinish'] == true,
        multiplier: (j['multiplier'] as num).toInt(),
        scores: (j['scores'] as List).map((e) => (e as num).toInt()).toList(),
      );
}

class OkeyView {
  final int round;
  final int rounds;
  final int current;
  final String phase; // 'draw' | 'play'
  final int myIndex;
  final int deckCount;
  final OkeyTile indicator;
  final int okeyColor;
  final int okeyNumber;
  final List<OkeyTile> hand;
  final int? mustOpenTileId;
  final bool roundOver;
  final RoundResult? roundResult;
  final bool gameOver;
  final List<int>? ranking;
  final Map<String, dynamic>? lastEvent;
  final List<OkeySeat> players;

  const OkeyView({
    required this.round,
    required this.rounds,
    required this.current,
    required this.phase,
    required this.myIndex,
    required this.deckCount,
    required this.indicator,
    required this.okeyColor,
    required this.okeyNumber,
    required this.hand,
    required this.mustOpenTileId,
    required this.roundOver,
    required this.roundResult,
    required this.gameOver,
    required this.ranking,
    required this.lastEvent,
    required this.players,
  });

  bool get isMyTurn => current == myIndex && !roundOver && !gameOver;

  factory OkeyView.fromJson(Map<String, dynamic> j) {
    final okey = Map<String, dynamic>.from(j['okey'] as Map);
    return OkeyView(
      round: (j['round'] as num).toInt(),
      rounds: (j['rounds'] as num).toInt(),
      current: (j['current'] as num).toInt(),
      phase: j['phase'] as String,
      myIndex: (j['myIndex'] as num).toInt(),
      deckCount: (j['deckCount'] as num).toInt(),
      indicator: OkeyTile.fromJson(Map<String, dynamic>.from(j['indicator'] as Map)),
      okeyColor: (okey['c'] as num).toInt(),
      okeyNumber: (okey['n'] as num).toInt(),
      hand: (j['hand'] as List)
          .map((t) => OkeyTile.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList(),
      mustOpenTileId: (j['mustOpenTileId'] as num?)?.toInt(),
      roundOver: j['roundOver'] == true,
      roundResult: j['roundResult'] == null
          ? null
          : RoundResult.fromJson(Map<String, dynamic>.from(j['roundResult'] as Map)),
      gameOver: j['gameOver'] == true,
      ranking: (j['ranking'] as List?)?.map((e) => (e as num).toInt()).toList(),
      lastEvent: j['lastEvent'] == null ? null : Map<String, dynamic>.from(j['lastEvent'] as Map),
      players: (j['players'] as List)
          .map((p) => OkeySeat.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }
}

/// Oyun sonu ozeti (okey_over).
class OkeyOver {
  final List<int> ranking;
  final List<int> totals;
  final List<String> names;
  final int youPaid;
  const OkeyOver({required this.ranking, required this.totals, required this.names, required this.youPaid});

  factory OkeyOver.fromJson(Map<String, dynamic> j) => OkeyOver(
        ranking: (j['ranking'] as List).map((e) => (e as num).toInt()).toList(),
        totals: (j['totals'] as List).map((e) => (e as num).toInt()).toList(),
        names: (j['names'] as List).map((e) => e as String).toList(),
        youPaid: (j['youPaid'] as num?)?.toInt() ?? 0,
      );
}
