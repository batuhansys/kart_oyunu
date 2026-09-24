import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/game_city.dart';
import '../../features/account/account_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/city_select/city_select_screen.dart';
import '../../features/daily_wheel/daily_wheel_screen.dart';
import '../../features/friends/friends_screen.dart';
import '../../features/game/game_table_screen.dart';
import '../../features/game_result/game_result_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/multiplayer/multiplayer_game_screen.dart';
import '../../features/multiplayer/multiplayer_lobby_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/royal_pass/royal_pass_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shop/shop_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/workshop/workshop_screen.dart';

/// Sayfalar arası yumuşak bir soluklaşma + hafif kayma geçişi
/// uygular. Varsayılan Material geçişine göre daha "premium" bir his
/// verir; tüm route'larda tutarlı şekilde kullanılır.
CustomTransitionPage<void> _fadeSlidePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.03),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) => _fadeSlidePage(state: state, child: const SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _fadeSlidePage(state: state, child: const LoginScreen()),
    ),
    GoRoute(
      path: '/register',
      pageBuilder: (context, state) => _fadeSlidePage(state: state, child: const RegisterScreen()),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => _fadeSlidePage(state: state, child: const HomeScreen()),
    ),
    GoRoute(
      path: '/shop',
      pageBuilder: (context, state) => _fadeSlidePage(state: state, child: const ShopScreen()),
    ),
    GoRoute(
      path: '/friends',
      pageBuilder: (context, state) => _fadeSlidePage(state: state, child: const FriendsScreen()),
    ),
    GoRoute(
      path: '/daily-wheel',
      pageBuilder: (context, state) => _fadeSlidePage(state: state, child: const DailyWheelScreen()),
    ),
    GoRoute(
      path: '/workshop',
      pageBuilder: (context, state) => _fadeSlidePage(state: state, child: const WorkshopScreen()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => _fadeSlidePage(state: state, child: const SettingsScreen()),
    ),
    GoRoute(
      path: '/account',
      pageBuilder: (context, state) => _fadeSlidePage(state: state, child: const AccountScreen()),
    ),
    GoRoute(
      path: '/notifications',
      pageBuilder: (context, state) =>
          _fadeSlidePage(state: state, child: const NotificationsScreen()),
    ),
    GoRoute(
      path: '/royal-pass',
      pageBuilder: (context, state) => _fadeSlidePage(state: state, child: const RoyalPassScreen()),
    ),
    GoRoute(
      path: '/city-select',
      pageBuilder: (context, state) =>
          _fadeSlidePage(state: state, child: const CitySelectScreen()),
    ),
    GoRoute(
      path: '/game',
      pageBuilder: (context, state) {
        final city = state.extra as GameCity;
        return _fadeSlidePage(state: state, child: GameTableScreen(city: city));
      },
    ),
    GoRoute(
      path: '/multiplayer',
      pageBuilder: (context, state) =>
          _fadeSlidePage(state: state, child: const MultiplayerLobbyScreen()),
    ),
    GoRoute(
      path: '/multiplayer/game',
      pageBuilder: (context, state) =>
          _fadeSlidePage(state: state, child: const MultiplayerGameScreen()),
    ),
    GoRoute(
      path: '/game-result',
      pageBuilder: (context, state) {
        final args = state.extra as GameResultArgs;
        return _fadeSlidePage(state: state, child: GameResultScreen(args: args));
      },
    ),
  ],
);
