/**
 * OkeyScout — App Root
 *
 * Navigation state machine:
 *
 *   [splash]         → auto-sign-in anonymously → home
 *   [home]           → HomeScreen (Start Game / Profile)
 *   [create-join]    → CreateJoinTableScreen
 *   [lobby]          → LobbyScreen (4 players, gösterge selection)
 *   [scanner]        → CameraScannerScreen (tile scan or QR scan)
 *   [game]           → GameScreen (actual game — stub for now)
 *   [score]          → ScoreScreen (hand result display)
 *
 * Deep links: okey://join/<CODE>  → auto-join table <CODE>
 */

import React, { useState, useEffect, useCallback, useRef } from 'react';
import { View, ActivityIndicator, StyleSheet, Text } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

// ── Screens ──────────────────────────────────────────────────────────────────
import HomeScreen              from './src/screens/HomeScreen';
import CreateJoinTableScreen   from './src/screens/CreateJoinTableScreen';
import LobbyScreen             from './src/screens/LobbyScreen';
import CameraScannerScreen     from './src/screens/CameraScannerScreen';
import ScoreScreen             from './src/screens/ScoreScreen';
import GameScreen              from './src/screens/GameScreen'; // stub

// ── Supabase ────────────────────────────────────────────────────────────────
import {
  getSupabase,
  signInAnonymously,
  getCurrentUserId,
} from './src/services/supabase';
import type { GöstergeTile } from './src/services/supabase';
import type { Tile, SiegerTyp }         from './src/utils/okeyEngine';
import type { ScanResult }   from './src/screens/CameraScannerScreen';

// ── Types ───────────────────────────────────────────────────────────────────

type Screen =
  | 'splash'
  | 'home'
  | 'create-join'
  | 'lobby'
  | 'scanner'
  | 'game'
  | 'score';

type RootStackParamList = {
  Home:           undefined;
  CreateJoin:     undefined;
  Lobby:          { tableId: string };
  Scanner:        { mode: 'rack' | 'qr'; tableId?: string; gösterge?: GöstergeTile };
  Game:           { tableId: string; gösterge: GöstergeTile; userId: string };
  Score:          { tableId?: string; gösterge: GöstergeTile; hand: Tile[]; winType: string; winnerDiscardedOkey: boolean; fotoGemacht?: boolean };
};

const Stack = createNativeStackNavigator<RootStackParamList>();

// ─────────────────────────────────────────────────────────────────────────────
// App Root Component
// ─────────────────────────────────────────────────────────────────────────────

export default function App() {
  const [initializing, setInitializing] = useState(true);
  const [userId,      setUserId]      = useState<string | null>(null);
  const [username,    setUsername]    = useState<string>('Spieler');

  // Deep link navigation ref (needed to navigate from outside screen context)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const navigationRef = useRef<any>(null);
  // Pending auto-join table code from deep link
  const autoJoinRef = useRef<string | null>(null);

  // ── Boot: anonymous sign-in ───────────────────────────────────────────
  useEffect(() => {
    async function bootstrap() {
      let uid = await getCurrentUserId();

      if (!uid) {
        uid = await signInAnonymously();
      }

      if (uid) {
      setUserId(uid);
      // Fetch username from profiles
      const { data } = await getSupabase()
        .from('profiles')
        .select('username')
        .eq('id', uid)
        .single();
      const usernameData = data as { username: string } | null;
      if (usernameData?.username) setUsername(usernameData.username);
      }

      setInitializing(false);
    }

    bootstrap();
  }, []);

  // ── Handle deep link: okey://join/<CODE> ────────────────────────────
  useEffect(() => {
    async function handleDeepLink(event: { url: string }) {
      const url = event.url;
      const match = url.match(/okey:\/\/join\/(\d{4})/);
      if (match) {
        const tableCode = match[1];
        // Navigate to CreateJoin with auto-join of tableCode
        // We use replace to avoid stacking history
        navigationRef.current?.navigate('CreateJoin', {});
        // Give the screen a moment to mount, then trigger auto-join
        setTimeout(() => {
          // The CreateJoinScreen checks URL params on mount for auto-join
          autoJoinRef.current = tableCode;
        }, 100);
      }
    }

    // expo-linking for React Native / Expo
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { addEventListener } = require('expo-linking');

    // Check if app was opened via deep link at startup
    const initialUrl = require('expo-linking').createURL('/');
    const match = initialUrl.match(/okey:\/\/join\/(\d{4})/);
    if (match) {
      autoJoinRef.current = match[1];
    }

    const subscription = addEventListener('url', handleDeepLink);
    return () => subscription.remove();
  }, []);

  // ── Navigation callbacks ───────────────────────────────────────────────
  const handleCreateJoined = useCallback((tableId: string) => {
    // Called from CreateJoinTableScreen when successfully joined/created a table
    // Navigation will be handled by the stack navigator
  }, []);

  const handleScanComplete = useCallback((result: ScanResult) => {
    // Called from CameraScannerScreen with detected tiles
    // Navigation to ScoreScreen handled by the navigator
  }, []);

  // ── Render ────────────────────────────────────────────────────────────
  if (initializing) {
    return (
      <View style={styles.loading}>
        <ActivityIndicator size="large" color="#e94560" />
        <Text style={styles.loadingText}>OkeyScout wird geladen…</Text>
      </View>
    );
  }

  return (
    <NavigationContainer>
      <Stack.Navigator
        initialRouteName="Home"
        screenOptions={{
          headerShown: false,
          animation:   'slide_from_right',
          contentStyle: { backgroundColor: '#0f0f1a' },
        }}
      >
        {/* Home */}
        <Stack.Screen name="Home">
          {({ navigation }) => (
            <HomeScreen
              username={username}
              onStartGame={() => navigation.navigate('CreateJoin')}
              onViewProfile={() => {}}
            />
          )}
        </Stack.Screen>

        {/* Create or Join Table */}
        <Stack.Screen name="CreateJoin">
          {({ navigation, route }) => (
            <CreateJoinTableScreen
              userId={userId ?? ''}
              onJoinedTable={(tableId) => {
                navigation.replace('Lobby', { tableId });
              }}
              onGoBack={() => navigation.goBack()}
            />
          )}
        </Stack.Screen>

        {/* Lobby */}
        <Stack.Screen name="Lobby">
          {({ navigation, route }) => (
            <LobbyScreen
              navigation={navigation}
              tableId={route.params.tableId}
              userId={userId ?? ''}
              username={username}
              onStartRound={(gösterge) => {
                navigation.replace('Game', {
                  tableId:   route.params.tableId,
                  gösterge,
                  userId:    userId ?? '',
                });
              }}
              onLeaveTable={() => navigation.navigate('Home')}
              onGoBack={() => navigation.goBack()}
            />
          )}
        </Stack.Screen>

        {/* Camera Scanner */}
        <Stack.Screen name="Scanner">
          {({ navigation, route }) => (
            <CameraScannerScreen
              gösterge={route.params.gösterge}
              onScanComplete={(result) => {
                navigation.navigate('Score', {
                  tableId: route.params.tableId,
                  gösterge: route.params.gösterge ?? { color: 'RED', number: 5 },
                  hand:     result.tiles,
                  winType:  'NORMAL',
                  winnerDiscardedOkey: false,
                  fotoGemacht: false,
                });
              }}
              onScanQRCode={() => {
                // Close camera, go back to join screen
                navigation.navigate('CreateJoin');
              }}
              onGoBack={() => navigation.goBack()}
            />
          )}
        </Stack.Screen>

        {/* Game (stub) */}
        <Stack.Screen name="Game">
          {({ navigation, route }) => {
            const { tableId, gösterge } = route.params;
            return (
              <GameScreen
                tableId={tableId}
                gösterge={gösterge}
                userId={route.params.userId}
                onFinishHand={(hand, winnerDiscardedOkey, winnerPairedOnly) => {
                  const winType: SiegerTyp = winnerPairedOnly
                    ? (winnerDiscardedOkey ? 'OKEY_CIFTE' : 'CIFTE')
                    : (winnerDiscardedOkey ? 'OKEY' : 'NORMAL');
                  navigation.navigate('Score', {
                    tableId,
                    gösterge,
                    hand,
                    winType,
                    winnerDiscardedOkey,
                    fotoGemacht: false,
                  });
                }}
                onLeaveTable={() => navigation.navigate('Home')}
              />
            );
          }}
        </Stack.Screen>

        {/* Score */}
        <Stack.Screen name="Score">
          {({ navigation, route }) => (
            <ScoreScreen
              tableId={route.params.tableId}
              gösterge={route.params.gösterge}
              hand={route.params.hand}
              winType={(route.params as any).winType ?? 'NORMAL'}
              winnerDiscardedOkey={route.params.winnerDiscardedOkey ?? false}
              fotoGemacht={route.params.fotoGemacht ?? false}
              onBack={() => navigation.goBack()}
              onScanAgain={() => navigation.navigate('Scanner', { mode: 'rack', tableId: route.params.tableId, gösterge: route.params.gösterge })}
            />
          )}
        </Stack.Screen>
      </Stack.Navigator>
    </NavigationContainer>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Styles
// ─────────────────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  loading: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#0f0f1a',
    gap: 16,
  },
  loadingText: {
    color:     '#fff',
    fontSize:  16,
  },
});
