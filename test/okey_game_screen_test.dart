import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:risk_get_and_gain/domain/entities/okey_models.dart';
import 'package:risk_get_and_gain/features/okey/okey_game_screen.dart';
import 'package:risk_get_and_gain/state/multiplayer/multiplayer_notifier.dart';
import 'package:risk_get_and_gain/state/multiplayer/multiplayer_state.dart';
import 'package:risk_get_and_gain/state/power_provider.dart';

class _FakeNotifier extends MultiplayerNotifier {
  _FakeNotifier(MultiplayerState initial) {
    state = initial;
  }

  @override
  Future<ArrangeResult?> requestArrange() async => null;
  @override
  void requestPreview(List<List<int>> groups) {}
}

Map<String, dynamic> _tile(int id, int c, int n) => {'id': id, 'c': c, 'n': n};

Map<String, dynamic> _seat(int i, {int hand = 14, bool opened = false, List<Map<String, dynamic>> melds = const []}) => {
      'seat': i,
      'name': 'Oyuncu $i',
      'handCount': hand,
      'opened': opened,
      'mode': opened ? 'melds' : null,
      'total': 101 * i,
      'roundScore': 0,
      'powerUsed': null,
      'discardTop': i == 3 ? _tile(900, 2, 9) : null,
      'discardCount': i == 3 ? 1 : 0,
      'melds': melds,
    };

OkeyView _view({bool roundOver = false, bool gameOver = false, bool myTurn = true}) {
  final hand = [for (var i = 0; i < 15; i++) _tile(i, i % 4, (i % 13) + 1)];
  return OkeyView.fromJson({
    'round': 1,
    'rounds': 3,
    'current': myTurn ? 0 : 1,
    'phase': 'play',
    'myIndex': 0,
    'deckCount': 40,
    'indicator': _tile(500, 1, 4),
    'okey': {'c': 1, 'n': 5},
    'hand': hand,
    'mustOpenTileId': null,
    'roundOver': roundOver,
    'roundResult': roundOver ? {'winner': 1, 'okeyFinish': false, 'multiplier': 1, 'scores': [202, -101, 40, 202]} : null,
    'gameOver': gameOver,
    'ranking': gameOver ? [1, 2, 0, 3] : null,
    'lastEvent': {'type': 'deal'},
    'players': [
      _seat(0, hand: 15),
      _seat(1, opened: true, melds: [
        {
          'type': 'run',
          'tiles': [
            {..._tile(600, 0, 3), 'as': {'c': 0, 'n': 3}},
            {..._tile(601, 0, 4), 'as': {'c': 0, 'n': 4}},
            {..._tile(602, 1, 5), 'j': 1, 'as': {'c': 0, 'n': 5}},
          ],
        },
      ]),
      _seat(2),
      _seat(3),
    ],
  });
}

Future<void> _pump(WidgetTester tester, Size size, MultiplayerState st) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [GoRoute(path: '/', builder: (c, s) => const OkeyGameScreen())]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        multiplayerProvider.overrideWith((ref) => _FakeNotifier(st)),
        powerInventoryProvider.overrideWith((ref) => PowerInventoryNotifier(null, null)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  for (final size in const [Size(800, 360), Size(640, 300), Size(530, 240), Size(1000, 460)]) {
    testWidgets('Okey masasi ${size.width.toInt()}x${size.height.toInt()} tasma olmadan cizilir', (tester) async {
      await _pump(tester, size, MultiplayerState(stage: MpStage.playing, view: _view(), humans: const [true, false, false, false]));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('El 1/3'), findsOneWidget);
    });
  }

  testWidgets('El sonu paneli cizilir', (tester) async {
    await _pump(tester, const Size(800, 360), MultiplayerState(stage: MpStage.playing, view: _view(roundOver: true, myTurn: false)));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('eli bitirdi'), findsOneWidget);
  });

  testWidgets('Oyun sonu paneli cizilir', (tester) async {
    await _pump(
      tester,
      const Size(800, 360),
      MultiplayerState(
        stage: MpStage.finished,
        view: _view(roundOver: true, gameOver: true, myTurn: false),
        over: const OkeyOver(ranking: [1, 2, 0, 3], totals: [202, 0, 50, 300], names: ['A', 'B', 'C', 'D'], youPaid: 0),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Lobiye Dön'), findsOneWidget);
  });
}
