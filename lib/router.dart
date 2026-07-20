// lib/router.dart
// RenkliOkeyScout — GoRouter navigation

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/demo_lobby_screen.dart';
import 'screens/demo_active_round_screen.dart';
import 'screens/demo_round_result_screen.dart';
import 'screens/demo_game_over_screen.dart';
import 'screens/demo_round_setup_screen.dart';
import 'screens/gosterge_screen.dart';
import 'screens/active_round_screen.dart';
import 'screens/round_result_screen.dart';
import 'screens/game_over_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/rules_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;
    final isHome = state.matchedLocation == '/';
    // Demo routes are auth-free
    final isDemo = state.matchedLocation.startsWith('/demo');
    if (user == null && !isHome && !isDemo) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/lobby',
      builder: (context, state) => const LobbyScreen(),
    ),
    GoRoute(
      path: '/demo-lobby',
      builder: (context, state) => const DemoLobbyScreen(),
    ),
    GoRoute(
      path: '/demo-setup',
      builder: (context, state) => const DemoRoundSetupScreen(),
    ),
    GoRoute(
      path: '/demo-round',
      builder: (context, state) => const DemoActiveRoundScreen(),
    ),
    GoRoute(
      path: '/demo-round-result',
      builder: (context, state) => const DemoRoundResultScreen(),
    ),
    GoRoute(
      path: '/demo-gameover',
      builder: (context, state) => const DemoGameOverScreen(),
    ),
    GoRoute(
      path: '/gosterge/:tableId/:roundNumber',
      builder: (context, state) {
        final tableId = state.pathParameters['tableId']!;
        final roundNumber = int.parse(state.pathParameters['roundNumber']!);
        return GostergeScreen(tableId: tableId, roundNumber: roundNumber);
      },
    ),
    GoRoute(
      path: '/round/:tableId',
      builder: (context, state) {
        final tableId = state.pathParameters['tableId']!;
        return ActiveRoundScreen(tableId: tableId);
      },
    ),
    GoRoute(
      path: '/round-result/:tableId/:roundNumber',
      builder: (context, state) {
        final tableId = state.pathParameters['tableId']!;
        final roundNumber = int.parse(state.pathParameters['roundNumber']!);
        return RoundResultScreen(tableId: tableId, roundNumber: roundNumber);
      },
    ),
    GoRoute(
      path: '/gameover/:tableId',
      builder: (context, state) {
        final tableId = state.pathParameters['tableId']!;
        return GameOverScreen(tableId: tableId);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/rules',
      builder: (context, state) => const RulesScreen(),
    ),
  ],
);
