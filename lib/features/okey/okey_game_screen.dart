import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/okey_models.dart';
import '../../state/multiplayer/multiplayer_notifier.dart';
import '../../state/multiplayer/multiplayer_state.dart';
import 'widgets/okey_tile_view.dart';
import 'widgets/power_box_row.dart';

const int _kCols = 14;
const int _kSlots = _kCols * 2;
const Color _kFelt = Color(0xFF0E5A3A);
const Color _kFeltDark = Color(0xFF083A25);

/// 101 Okey masasi. Tum kurallar sunucuda (server/okey); burasi gosterim +
/// surukle-birak raf yonetimidir. Raf dizilimi sadece istemcide tutulur,
/// sunucuya yalniz tas id'leri gider.
class OkeyGameScreen extends ConsumerStatefulWidget {
  const OkeyGameScreen({super.key});

  @override
  ConsumerState<OkeyGameScreen> createState() => _OkeyGameScreenState();
}

class _OkeyGameScreenState extends ConsumerState<OkeyGameScreen> {
  final List<int?> _slots = List<int?>.filled(_kSlots, null);
  int? _preferredSlot;
  int? _selectedId;
  int _lastRound = -1;
  bool _arranging = false;
  Timer? _tick;
  Timer? _previewDebounce;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final v = ref.read(multiplayerProvider).view;
      if (v != null) _syncRack(v);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _previewDebounce?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- raf
  Map<int, OkeyTile> _handMap(OkeyView v) => {for (final t in v.hand) t.id: t};

  void _syncRack(OkeyView v) {
    final ids = v.hand.map((t) => t.id).toSet();
    final newRound = v.round != _lastRound;
    if (newRound) {
      for (var i = 0; i < _kSlots; i++) {
        _slots[i] = null;
      }
      _lastRound = v.round;
    }
    for (var i = 0; i < _kSlots; i++) {
      if (_slots[i] != null && !ids.contains(_slots[i])) _slots[i] = null;
    }
    final present = _slots.whereType<int>().toSet();
    for (final t in v.hand) {
      if (present.contains(t.id)) continue;
      int target = -1;
      if (_preferredSlot != null && _slots[_preferredSlot!] == null) {
        target = _preferredSlot!;
      } else {
        target = _pickFreeSlot();
      }
      if (target >= 0) {
        _slots[target] = t.id;
        present.add(t.id);
      }
    }
    _preferredSlot = null;
    if (newRound && v.hand.isNotEmpty) _autoArrange();
    _requestPreview();
    if (mounted) setState(() {});
  }

  /// Yeni tas: yanlis per birlesmesin diye komsulari bos (izole) en sagdaki
  /// bos yuvaya; yoksa ilk bos yuvaya konur.
  int _pickFreeSlot() {
    for (var i = _kSlots - 1; i >= 0; i--) {
      if (_slots[i] != null) continue;
      final col = i % _kCols;
      final leftFree = col == 0 || _slots[i - 1] == null;
      final rightFree = col == _kCols - 1 || _slots[i + 1] == null;
      if (leftFree && rightFree) return i;
    }
    return _slots.indexWhere((s) => s == null);
  }

  Future<void> _autoArrange() async {
    if (_arranging) return;
    _arranging = true;
    final res = await ref.read(multiplayerProvider.notifier).requestArrange();
    _arranging = false;
    if (!mounted) return;
    final v = ref.read(multiplayerProvider).view;
    if (v == null) return;
    final hand = _handMap(v);
    List<List<int>> groups = [];
    List<int> rest;
    if (res == null) {
      rest = hand.keys.toList();
    } else {
      groups = res.groups.map((g) => g.where(hand.containsKey).toList()).where((g) => g.isNotEmpty).toList();
      rest = res.rest.where(hand.containsKey).toList();
    }
    rest.sort((a, b) {
      final ta = hand[a]!;
      final tb = hand[b]!;
      if (ta.joker != tb.joker) return ta.joker ? -1 : 1;
      return ta.color != tb.color ? ta.color.compareTo(tb.color) : ta.number.compareTo(tb.number);
    });
    _applyLayout(groups, rest);
  }

  void _applyLayout(List<List<int>> groups, List<int> rest) {
    final out = List<int?>.filled(_kSlots, null);
    var pos = 0;
    void block(List<int> ids, {bool gap = true}) {
      final col = pos % _kCols;
      if (col != 0 && col + ids.length > _kCols) pos += _kCols - col;
      for (final id in ids) {
        if (pos < _kSlots) out[pos++] = id;
      }
      if (gap) pos++;
    }

    for (final g in groups) {
      block(g);
    }
    // Per olmayan taslar bitisik dizilir; yanlis per sayilmasinlar diye
    // gonderim sirasinda sunucu onizlemesiyle (gecersiz) elenirler.
    if (rest.isNotEmpty) block(rest, gap: false);
    setState(() {
      for (var i = 0; i < _kSlots; i++) {
        _slots[i] = out[i];
      }
    });
    _requestPreview();
  }

  List<List<int>> _segments() {
    final segs = <List<int>>[];
    for (var r = 0; r < 2; r++) {
      var cur = <int>[];
      for (var c = 0; c < _kCols; c++) {
        final id = _slots[r * _kCols + c];
        if (id != null) {
          cur.add(id);
        } else {
          if (cur.length >= 2) segs.add(cur);
          cur = [];
        }
      }
      if (cur.length >= 2) segs.add(cur);
    }
    return segs;
  }

  List<List<int>> _layGroups() {
    final segs = _segments();
    final melds = segs.where((s) => s.length >= 3).toList();
    if (melds.isNotEmpty) return melds;
    return segs.where((s) => s.length == 2).toList();
  }

  void _requestPreview() {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 250), () {
      final st = ref.read(multiplayerProvider);
      final v = st.view;
      if (!mounted || v == null || st.stage != MpStage.playing) return;
      final groups = _layGroups();
      if (groups.isEmpty) return;
      ref.read(multiplayerProvider.notifier).requestPreview(groups);
    });
  }

  void _moveToSlot(int tileId, int slot) {
    final from = _slots.indexOf(tileId);
    if (from == -1 || from == slot) return;
    setState(() {
      final other = _slots[slot];
      _slots[slot] = tileId;
      _slots[from] = other;
    });
    _requestPreview();
  }

  void _doLay(MultiplayerState st) {
    final groups = _layGroups();
    if (groups.isEmpty) {
      _toast('Önce taşları yan yana dizerek per oluştur (per arasında boşluk bırak).');
      return;
    }
    // Onizleme gecersiz dedigi perleri gonderme (rastgele bitisik taslar).
    final pv = st.preview;
    var send = groups;
    if (pv != null && pv.types.length == groups.length) {
      final valid = <List<int>>[];
      for (var i = 0; i < groups.length; i++) {
        if (pv.types[i] != null) valid.add(groups[i]);
      }
      if (valid.isNotEmpty) send = valid;
    }
    HapticFeedback.mediumImpact();
    ref.read(multiplayerProvider.notifier).layMelds(send);
  }

  String? _toastText;
  Timer? _toastTimer;

  /// Oyun ici kisa bildirim (SnackBar yerine ust banner: her ekran boyutunda gorunur).
  void _toast(String m) {
    if (!mounted) return;
    setState(() => _toastText = m);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _toastText = null);
    });
  }

  // --------------------------------------------------------------- cikis
  void _confirmLeave() {
    final st = ref.read(multiplayerProvider);
    if (st.stage == MpStage.finished) {
      _leave();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Masadan Kalk', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Masadan kalkarsan giriş ücretini kaybedersin ve yerine bot oturur. Emin misin?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Oyuna Dön')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _leave();
            },
            child: const Text('Kalk', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _leave() {
    ref.read(multiplayerProvider.notifier).leaveTable();
    if (context.canPop()) context.pop();
  }

  // ----------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final st = ref.watch(multiplayerProvider);
    final view = st.view;

    ref.listen<MultiplayerState>(multiplayerProvider, (prev, next) {
      if (next.view != null && next.view != prev?.view) _syncRack(next.view!);
      if (next.toast != null && next.toast != prev?.toast) {
        _toast(next.toast!);
        ref.read(multiplayerProvider.notifier).clearToast();
      }
      if (next.stage == MpStage.disconnected && prev?.stage != MpStage.disconnected) {
        _toast(next.errorMessage ?? 'Bağlantı koptu.');
        if (context.canPop()) context.pop();
      }
    });

    if (view == null) {
      return const Scaffold(
        backgroundColor: _kFeltDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    final me = view.myIndex;
    final prev = (me + 3) % 4;
    final across = (me + 2) % 4;
    final next = (me + 1) % 4;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: _kFeltDark,
        body: SafeArea(
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(center: Alignment.center, radius: 1.3, colors: [_kFelt, _kFeltDark]),
                ),
                child: LayoutBuilder(builder: (context, c) {
                  final h = c.maxHeight;
                  final rackBlockH = (h * 0.40).clamp(104.0, 160.0);
                  return Column(
                    children: [
                      _topBar(st, view),
                      _opponentStrip(view, [prev, across, next]),
                      Expanded(child: _middle(st, view, prev)),
                      SizedBox(height: rackBlockH, child: _rackBlock(st, view, rackBlockH)),
                    ],
                  );
                }),
              ),
              if (st.peekTile != null) _peekBanner(st.peekTile!),
              if (_toastText != null) _toastBanner(_toastText!),
              if (view.roundOver && !view.gameOver) _roundOverlay(st, view),
              if (st.stage == MpStage.finished) _gameOverOverlay(st, view),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- ust bar
  String _statusText(OkeyView v) {
    if (ref.read(multiplayerProvider).connectionLost) return 'Bağlantı koptu, yeniden bağlanılıyor... (bot senin yerine oynuyor)';
    if (v.roundOver) return 'El bitti';
    final cur = v.players[v.current];
    if (v.current == v.myIndex) {
      if (v.mustOpenTileId != null) return 'Yerden taş aldın: elini açmalısın!';
      return v.phase == 'draw' ? 'Sıra sende: taş çek' : 'Sıra sende: per diz / taş at';
    }
    return '${cur.name} oynuyor...';
  }

  Widget _topBar(MultiplayerState st, OkeyView v) {
    final left = st.deadlineMs == null ? null : ((st.deadlineMs! - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    final mine = v.isMyTurn;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.black26,
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 32),
            icon: const Icon(Icons.exit_to_app, size: 20, color: Colors.white70),
            tooltip: 'Masadan Kalk',
            onPressed: _confirmLeave,
          ),
          Text('El ${v.round}/${v.rounds}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Gösterge ve okey',
            child: Row(
              children: [
                OkeyTileView(color: v.indicator.color, number: v.indicator.number, width: 17),
                const SizedBox(width: 4),
                Text('Okey: ${kOkeyColorNames[v.okeyColor]} ${v.okeyNumber}',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusText(v),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: mine ? AppColors.gold : Colors.white60,
                fontWeight: mine ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
          if (left != null && mine && !v.roundOver)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: left <= 10 ? AppColors.foldRed : Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${left.clamp(0, 99)}s', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          PowerBoxRow(canUse: mine, usedPower: v.players[v.myIndex].powerUsed),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- rakipler
  Widget _opponentStrip(OkeyView v, List<int> seats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            for (final s in seats) Expanded(child: _opponentChip(v, v.players[s])),
          ],
        ),
      ),
    );
  }

  Widget _opponentChip(OkeyView v, OkeySeat p) {
    final active = v.current == p.seat && !v.roundOver;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? AppColors.gold : Colors.white12, width: active ? 2 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Icon(Icons.view_module, size: 12, color: Colors.white54),
                    const SizedBox(width: 2),
                    Text('${p.handCount}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    const SizedBox(width: 6),
                    Text('Puan ${p.total}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
                if (p.opened)
                  Text(p.mode == 'pairs' ? 'ÇİFT AÇTI' : 'AÇTI',
                      style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
            ),
          ),
          if (p.discardTop != null)
            OkeyTileView(
              color: p.discardTop!.color,
              number: p.discardTop!.number,
              fake: p.discardTop!.fake,
              joker: p.discardTop!.joker,
              width: 22,
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- orta alan
  Widget _middle(MultiplayerState st, OkeyView v, int prevSeat) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      child: Row(
        children: [
          Expanded(child: _tableMelds(v)),
          const SizedBox(width: 6),
          SizedBox(width: 168, child: _centerPiles(v, prevSeat)),
        ],
      ),
    );
  }

  Widget _tableMelds(OkeyView v) {
    final items = <Widget>[];
    for (final p in v.players) {
      for (var i = 0; i < p.melds.length; i++) {
        items.add(_meldBox(v, p, i));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(6),
      child: items.isEmpty
          ? const Center(
              child: Text(
                'Masa boş\nAçılan perler burada görünür.\nAçtıktan sonra taşı bir pere sürükleyerek işleyebilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            )
          : SingleChildScrollView(child: Wrap(spacing: 6, runSpacing: 6, children: items)),
    );
  }

  Widget _meldBox(OkeyView v, OkeySeat owner, int meldIdx) {
    final meld = owner.melds[meldIdx];
    final mine = owner.seat == v.myIndex;
    final canDrop = v.isMyTurn && v.phase == 'play' && meld.type != 'pair';
    return DragTarget<Object>(
      onWillAcceptWithDetails: (d) => canDrop && d.data is int,
      onAcceptWithDetails: (d) =>
          ref.read(multiplayerProvider.notifier).addToMeld(d.data as int, owner.seat, meldIdx),
      builder: (context, cand, _) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: cand.isNotEmpty ? AppColors.gold.withOpacity(0.35) : Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: mine ? AppColors.gold.withOpacity(0.6) : Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(owner.name, style: const TextStyle(color: Colors.white54, fontSize: 8)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mt in meld.tiles)
                  Padding(
                    padding: const EdgeInsets.only(right: 1),
                    child: OkeyTileView(
                      color: mt.tile.joker ? mt.asColor : mt.tile.color,
                      number: mt.tile.joker ? mt.asNumber : mt.tile.number,
                      fake: mt.tile.fake,
                      joker: mt.tile.joker,
                      width: 19,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerPiles(OkeyView v, int prevSeat) {
    final canDraw = v.isMyTurn && v.phase == 'draw';
    final prevTop = v.players[prevSeat].discardTop;
    final notifier = ref.read(multiplayerProvider.notifier);
    const tw = 38.0;

    Widget label(String t) => Text(t, style: const TextStyle(color: Colors.white54, fontSize: 9));

    final deck = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Draggable<Object>(
          data: 'deck',
          maxSimultaneousDrags: canDraw ? 1 : 0,
          feedback: const Material(color: Colors.transparent, child: OkeyTileView(color: 0, number: 0, width: tw, faceDown: true)),
          childWhenDragging: const Opacity(opacity: 0.4, child: OkeyTileView(color: 0, number: 0, width: tw, faceDown: true)),
          child: GestureDetector(
            onTap: canDraw ? notifier.drawFromDeck : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const OkeyTileView(color: 0, number: 0, width: tw, faceDown: true),
                Text('${v.deckCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (canDraw)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppColors.gold, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        label('Deste'),
      ],
    );

    final take = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        prevTop == null
            ? Container(
                width: tw,
                height: tw * 1.4,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.white24)),
              )
            : Draggable<Object>(
                data: 'discard',
                maxSimultaneousDrags: canDraw ? 1 : 0,
                feedback: Material(
                  color: Colors.transparent,
                  child: OkeyTileView(color: prevTop.color, number: prevTop.number, fake: prevTop.fake, joker: prevTop.joker, width: tw),
                ),
                child: GestureDetector(
                  onTap: canDraw ? notifier.drawFromDiscard : null,
                  child: OkeyTileView(
                    color: prevTop.color,
                    number: prevTop.number,
                    fake: prevTop.fake,
                    joker: prevTop.joker,
                    width: tw,
                    highlight: canDraw,
                  ),
                ),
              ),
        label('Yerden Al'),
      ],
    );

    final discardZone = DragTarget<Object>(
      onWillAcceptWithDetails: (d) => v.isMyTurn && v.phase == 'play' && d.data is int,
      onAcceptWithDetails: (d) => notifier.discard(d.data as int),
      builder: (context, cand, _) => GestureDetector(
        onTap: () {
          final id = _selectedId;
          if (id == null) {
            _toast('Atmak için bir taşa dokun, sonra buraya dokun (ya da taşı buraya sürükle).');
            return;
          }
          _selectedId = null;
          notifier.discard(id);
        },
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: tw + 6,
            height: tw * 1.4,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cand.isNotEmpty ? AppColors.gold.withOpacity(0.35) : Colors.black26,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: cand.isNotEmpty ? AppColors.gold : Colors.white30, width: 1.5),
            ),
            child: const Icon(Icons.vertical_align_bottom, color: Colors.white54, size: 20),
          ),
          label('At'),
        ],
      ),
      ),
    );

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [deck, take, discardZone],
      ),
    );
  }

  // ------------------------------------------------------------------ raf
  Widget _rackBlock(MultiplayerState st, OkeyView v, double blockH) {
    final hand = _handMap(v);
    final mine = v.isMyTurn && v.phase == 'play';
    final pv = st.preview;
    final groups = _layGroups();
    final me = v.players[v.myIndex];

    String layLabel;
    if (!me.opened) {
      if (pv != null && pv.types.length == groups.length && groups.isNotEmpty) {
        layLabel = pv.pairs > 0 ? 'Çift Aç ${pv.pairs}/5' : 'Eli Aç ${pv.total}/101';
      } else {
        layLabel = 'Eli Aç';
      }
    } else {
      layLabel = me.mode == 'pairs' ? 'Çift İndir' : 'Per İndir';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              // Kutunun ic dolgusu (3+3) ve kenarligi (2+2) = 10px dusulur; her yuva
              // tas + 2 (kutu) + 1 (kenar boslugu) genisligindedir.
              final maxW = (c.maxWidth - 10) / _kCols - 3;
              final maxH = ((c.maxHeight - 12) / 2 - 3) / 1.4;
              final tw = (maxW < maxH ? maxW : maxH).clamp(18.0, 60.0);
              return Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF5D4037),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3E2723), width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var r = 0; r < 2; r++)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [for (var cI = 0; cI < _kCols; cI++) _slot(r * _kCols + cI, hand, v, tw)],
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 92,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _rackButton('Diz', Icons.auto_awesome, Colors.white24, Colors.white, _autoArrange),
                const SizedBox(height: 6),
                _rackButton(layLabel, Icons.file_download, AppColors.gold, Colors.black, mine ? () => _doLay(st) : null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rackButton(String label, IconData icon, Color bg, Color fg, VoidCallback? onTap) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: disabled ? bg.withOpacity(0.25) : bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: disabled ? Colors.white38 : fg),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: disabled ? Colors.white38 : fg, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slot(int index, Map<int, OkeyTile> hand, OkeyView v, double tw) {
    final id = _slots[index];
    final tile = id == null ? null : hand[id];
    final canDiscard = v.isMyTurn && v.phase == 'play';

    Widget tileWidget(OkeyTile t, {bool dim = false}) => OkeyTileView(
          color: t.color,
          number: t.number,
          fake: t.fake,
          joker: t.joker,
          width: tw,
          dim: dim,
          highlight: v.mustOpenTileId == t.id || _selectedId == t.id,
        );

    return DragTarget<Object>(
      onWillAcceptWithDetails: (d) => d.data is int || d.data == 'deck' || d.data == 'discard',
      onAcceptWithDetails: (d) {
        final data = d.data;
        if (data is int) {
          _moveToSlot(data, index);
        } else if (data == 'deck') {
          _preferredSlot = index;
          ref.read(multiplayerProvider.notifier).drawFromDeck();
        } else if (data == 'discard') {
          _preferredSlot = index;
          ref.read(multiplayerProvider.notifier).drawFromDiscard();
        }
      },
      builder: (context, cand, _) {
        final hovering = cand.isNotEmpty;
        return Container(
          width: tw + 2,
          height: tw * 1.4 + 2,
          margin: const EdgeInsets.symmetric(horizontal: 0.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tw * 0.14),
            color: hovering ? Colors.white24 : Colors.black12,
          ),
          alignment: Alignment.center,
          child: tile == null
              ? null
              : Draggable<Object>(
                  data: tile.id,
                  feedback: Material(color: Colors.transparent, child: tileWidget(tile)),
                  childWhenDragging: tileWidget(tile, dim: true),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedId = _selectedId == tile.id ? null : tile.id),
                    onDoubleTap: canDiscard ? () => ref.read(multiplayerProvider.notifier).discard(tile.id) : null,
                    child: tileWidget(tile),
                  ),
                ),
        );
      },
    );
  }

  // ------------------------------------------------------------- bindirmeler
  Widget _peekBanner(OkeyTile t) {
    return Positioned(
      top: 40,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.remove_red_eye, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              const Text('Destenin üstü: ', style: TextStyle(color: Colors.white70)),
              OkeyTileView(color: t.color, number: t.number, fake: t.fake, width: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toastBanner(String text) {
    return Positioned(
      top: 36,
      left: 40,
      right: 40,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.foldRed.withOpacity(0.95),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _scrim(Widget child) => Positioned.fill(
        child: Container(color: Colors.black87, alignment: Alignment.center, child: child),
      );

  Widget _scoreTable(OkeyView v, {required bool showRound}) {
    final rows = <TableRow>[
      TableRow(children: [
        const SizedBox(),
        const Text('Oyuncu', style: TextStyle(color: Colors.white54, fontSize: 11)),
        if (showRound) const Text('Bu el', textAlign: TextAlign.right, style: TextStyle(color: Colors.white54, fontSize: 11)),
        const Text('Toplam', textAlign: TextAlign.right, style: TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    ];
    for (final p in v.players) {
      final isWinner = v.roundResult?.winner == p.seat;
      rows.add(TableRow(children: [
        Icon(isWinner ? Icons.emoji_events : Icons.circle, size: 12, color: isWinner ? AppColors.gold : Colors.transparent),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(p.name + (p.seat == v.myIndex ? ' (Sen)' : ''), style: TextStyle(color: p.seat == v.myIndex ? AppColors.gold : Colors.white, fontSize: 13)),
        ),
        if (showRound)
          Text('${p.roundScore > 0 ? '+' : ''}${p.roundScore}', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text('${p.total}', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ]));
    }
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      columnWidths: const {0: FixedColumnWidth(18)},
      children: rows,
    );
  }

  Widget _roundOverlay(MultiplayerState st, OkeyView v) {
    final res = v.roundResult;
    final left = st.deadlineMs == null ? 0 : ((st.deadlineMs! - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, 99);
    String title;
    if (res == null || res.winner == null) {
      title = 'El berabere bitti (deste tükendi)';
    } else {
      final w = v.players[res.winner!];
      title = '${w.name}${res.winner == v.myIndex ? ' (Sen)' : ''} eli bitirdi!';
    }
    final extra = <String>[
      if (res != null && res.okeyFinish) 'Okey ile bitirdi: ceza x2',
      if (res != null && res.multiplier > 1 && !res.okeyFinish) 'Çift ile bitirdi: ceza x${res.multiplier}',
    ];
    return _scrim(
      Container(
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.gold)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold)),
            for (final e in extra) Text(e, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 8),
            _scoreTable(v, showRound: true),
            const SizedBox(height: 8),
            Text('Sonraki el: ${left}s', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _gameOverOverlay(MultiplayerState st, OkeyView v) {
    final over = st.over;
    final ranking = over?.ranking ?? v.ranking ?? [];
    final myRank = ranking.indexOf(v.myIndex);
    final pay = over?.youPaid ?? 0;
    return _scrim(
      Container(
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.gold, width: 2)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              myRank == 0 ? 'Kazandın! 🏆' : myRank >= 0 ? '${myRank + 1}. oldun' : 'Oyun bitti',
              style: TextStyle(color: myRank == 0 ? AppColors.gold : Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (pay > 0) Text('+$pay RC kazandın', style: const TextStyle(color: Colors.lightGreenAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (var i = 0; i < ranking.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${i + 1}. ${v.players[ranking[i]].name}${ranking[i] == v.myIndex ? ' (Sen)' : ''}',
                        style: TextStyle(color: ranking[i] == v.myIndex ? AppColors.gold : Colors.white, fontSize: 14)),
                    Text('${over?.totals[ranking[i]] ?? v.players[ranking[i]].total} puan', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
              onPressed: () {
                ref.read(multiplayerProvider.notifier).backToMenuAfterFinish();
                if (context.canPop()) context.pop();
              },
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8), child: Text('Lobiye Dön')),
            ),
          ],
        ),
      ),
    );
  }
}
