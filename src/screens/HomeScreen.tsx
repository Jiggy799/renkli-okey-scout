/**
 * OkeyScout — Home Screen
 * src/screens/HomeScreen.tsx
 *
 * Entry point of the app.
 * Shows: app logo, username, "Start Game" → Create/Join Table,
 *        "Scan Rack" → Camera Scanner, Profile button.
 */

import React, { useState } from 'react';
import {
  View, Text, TouchableOpacity, StyleSheet,
  StatusBar, TextInput, ScrollView,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import type { Tile, TileColor } from '../utils/okeyEngine';

type Props = {
  username:    string;
  onStartGame: () => void;
  onViewProfile: () => void;
};

export default function HomeScreen({ username, onStartGame, onViewProfile }: Props) {
  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#0f0f1a" />

      {/* Header */}
      <View style={styles.header}>
        <View>
          <Text style={styles.appName}>OkeyScout</Text>
          <Text style={styles.tagline}>On-device Okey Intelligence</Text>
        </View>
        <TouchableOpacity style={styles.profileBtn} onPress={onViewProfile}>
          <Text style={styles.profileBtnTxt}>{username[0]?.toUpperCase() ?? '?'}</Text>
        </TouchableOpacity>
      </View>

      {/* Hero */}
      <View style={styles.hero}>
        <Text style={styles.heroEmoji}>🀄</Text>
        <Text style={styles.heroTitle}>Willkommen, {username}!</Text>
        <Text style={styles.heroSub}>
          Spiele Okey mit KI-gestützter Kartenerkennung.{'\n'}
          Alles offline. Alles privat.
        </Text>
      </View>

      {/* Features */}
      <View style={styles.features}>
        <View style={styles.featureRow}>
          <Text style={styles.featureIcon}>📷</Text>
          <View>
            <Text style={styles.featureTitle}>KI-Scanner</Text>
            <Text style={styles.featureDesc}>Rack scannen, Tiles automatisch erkennen</Text>
          </View>
        </View>
        <View style={styles.featureRow}>
          <Text style={styles.featureIcon}>🔍</Text>
          <View>
            <Text style={styles.featureTitle}>Offline Engine</Text>
            <Text style={styles.featureDesc}>Keine Cloud. Alles auf deinem Gerät.</Text>
          </View>
        </View>
        <View style={styles.featureRow}>
          <Text style={styles.featureIcon}>👥</Text>
          <View>
            <Text style={styles.featureTitle}>Multiplayer</Text>
            <Text style={styles.featureDesc}>4 Spieler, Echtzeit-Lobby, QR-Code-Beitritt</Text>
          </View>
        </View>
      </View>

      {/* Actions */}
      <View style={styles.actions}>
        <TouchableOpacity style={styles.primaryBtn} onPress={onStartGame}>
          <Text style={styles.primaryBtnTxt}>🎮  Spiel starten</Text>
        </TouchableOpacity>

        <Text style={styles.version}>v1.0.0 · OkeyScout</Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },

  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 24,
    paddingTop: 8,
    paddingBottom: 16,
  },
  appName: {
    color: '#e94560',
    fontSize: 22,
    fontWeight: '900',
    letterSpacing: 1,
  },
  tagline: {
    color: 'rgba(255,255,255,0.38)',
    fontSize: 12,
    marginTop: 2,
  },
  profileBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(233,69,96,0.2)',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: 'rgba(233,69,96,0.4)',
  },
  profileBtnTxt: {
    color: '#e94560',
    fontSize: 18,
    fontWeight: '800',
  },

  hero: {
    alignItems: 'center',
    paddingVertical: 40,
    paddingHorizontal: 32,
  },
  heroEmoji: {
    fontSize: 72,
    marginBottom: 16,
  },
  heroTitle: {
    color: '#fff',
    fontSize: 26,
    fontWeight: '900',
    textAlign: 'center',
    marginBottom: 12,
  },
  heroSub: {
    color: 'rgba(255,255,255,0.55)',
    fontSize: 15,
    textAlign: 'center',
    lineHeight: 24,
  },

  features: {
    paddingHorizontal: 24,
    gap: 16,
    marginBottom: 32,
  },
  featureRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    backgroundColor: 'rgba(255,255,255,0.05)',
    borderRadius: 14,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.07)',
  },
  featureIcon: {
    fontSize: 28,
  },
  featureTitle: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '700',
  },
  featureDesc: {
    color: 'rgba(255,255,255,0.48)',
    fontSize: 13,
    marginTop: 2,
  },

  actions: {
    paddingHorizontal: 24,
    paddingBottom: 32,
    gap: 16,
  },
  primaryBtn: {
    backgroundColor: '#e94560',
    borderRadius: 14,
    paddingVertical: 18,
  },
  primaryBtnTxt: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '800',
    textAlign: 'center',
  },

  version: {
    color: 'rgba(255,255,255,0.2)',
    fontSize: 12,
    textAlign: 'center',
  },
});
