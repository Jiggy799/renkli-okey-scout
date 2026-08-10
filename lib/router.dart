// lib/router.dart
// RenkliOkeyScout — GoRouter navigation
//
// Startseite = /login (wenn nicht angemeldet)
// Nach Login → /
// Demo-Routen sind auth-frei.

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
import 'screens/collect_screen.dart';
import 'screens/login_screen.dart';
import 'screens/nickname_screen.dart';
import 'screens/profile_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Helper: Prüft ob der User einen Nickname braucht.
/// Anonymous User bekommen einen Auto-Nickname basierend auf ihrer UUID.
Future<bool> _needsNickname() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;
  // Anonymous User brauchen KEINEN Nickname-Screen — sie kriegen Auto-Nickname
  if (user.isAnonymous) return false;

  try {
    final res = await Supabase.instance.client
        .from('profiles')
        .select('username')
        .eq('id', user.id)
        .maybeSingle();
    return res == null || (res['username'] as String?)?.isEmpty == true;
  } catch (_) {
    return false;
  }
}

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) async {
    final user = Supabase.instance.client.auth.currentUser;
    final loc = state.matchedLocation;
    final isLogin = loc == '/login';
    final isNickname = loc == '/nickname';
    final isDemo = loc.startsWith('/demo');
    final isRules = loc == '/rules';
    final isSettings = loc == '/settings';

    // Öffentliche Routen — immer erlaubt, kein Redirect
    if (isLogin || isRules || isSettings) return null;

    // Nicht angemeldet → Login (außer Demo ist erlaubt)
    if (user == null && !isDemo) {
      return '/login';
    }
    // Anonymer User → direkt zum Home (kein Login nötig, kein Account-Upgrade möglich)
    if (user != null && user.isAnonymous && !isDemo) {
      return '/';
    }
    // Angemeldet aber auf /login → Nickname (oder Home wenn schon gesetzt)
    if (user != null && isLogin) {
      if (await _needsNickname()) return '/nickname';
      return '/';
    }
    // Angemeldet, hat aber keinen Nickname → /nickname
    if (user != null && !isNickname && !isDemo) {
      if (await _needsNickname()) return '/nickname';
    }
    // Auf /nickname aber Nickname existiert schon → /
    if (user != null && isNickname && !(await _needsNickname())) {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/nickname',
      builder: (context, state) => const NicknameScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
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
    GoRoute(
      path: '/collect',
      builder: (context, state) => const CollectScreen(),
    ),
  ],
);
