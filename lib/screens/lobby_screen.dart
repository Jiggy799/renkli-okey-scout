// ignore_for_file: depend_on_referenced_packages, unnecessary_import
// lib/screens/lobby_screen.dart
// RenkliOkeyScout — Lobby: Host table / Join via QR

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';

import 'gosterge_screen.dart';

const _scheme = 'okeyscout';
const _tableCodeLength = 4;

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _supabase = Supabase.instance.client;
  final _usernameController = TextEditingController();

  bool _isHost = false;
  String? _hostedTableId;
  String? _joinedTableId;
  List<Map<String, dynamic>> _players = [];
  bool _isScanning = false;
  bool _isLoading = false;

  String? _localUserId;

  @override
  void initState() {
    super.initState();
    _initLocalUser();
  }

  Future<void> _initLocalUser() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _localUserId = user.id;
      await _supabase
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
    }
    if (mounted) setState(() {});
  }

  RealtimeChannel? _lobbyChannel;

  void _subscribeToLobby() {
    _lobbyChannel?.unsubscribe();
    _lobbyChannel = _supabase.channel('lobby');

    _lobbyChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'table_players',
          callback: (payload) {
            final tableId = _hostedTableId ?? _joinedTableId;
            if (tableId != null) _loadPlayers(tableId);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tables',
          callback: (payload) {
            final newRow = payload.newRecord;
            if (newRow.isEmpty) return;
            final newStatus = newRow['status'] as String?;
            final rowId = newRow['id'] as String?;
            if (newStatus == 'playing' &&
                (rowId == _hostedTableId || rowId == _joinedTableId)) {
              _navigateToRound(rowId!);
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadPlayers(String tableId) async {
    final result = await _supabase
        .from('table_players')
        .select('*, profiles(username, avatar_url)')
        .eq('table_id', tableId)
        .order('seat_index');
    if (mounted) {
      setState(() => _players = List<Map<String, dynamic>>.from(result));
    }
  }

  // ─── Host a table ─────────────────────────────────────────────────────────

  Future<void> _hostTable() async {
    final username = _usernameController.text.trim().isNotEmpty
        ? _usernameController.text.trim()
        : 'Gast_${Random().nextInt(9999)}';

    setState(() => _isLoading = true);

    try {
      final code = _generateCode();
      var user = _supabase.auth.currentUser;

      // Sign in anonymously if not logged in
      if (user == null) {
        final anonResult = await _supabase.auth.signInAnonymously();
        user = anonResult.user;
      }

      // Ensure profile
      await _supabase.from('profiles').upsert({
        'id': user!.id,
        'username': username,
      });

      // Create table
      await _supabase.from('tables').insert({
        'id': code,
        'status': 'lobby',
        'created_by': user.id,
      });

      // Add self as player
      await _supabase.from('table_players').insert({
        'table_id': code,
        'player_id': user.id,
        'seat_index': 0,
        'is_creator': true,
        'is_ready': true,
      });

      setState(() {
        _isHost = true;
        _hostedTableId = code;
        _isLoading = false;
        _localUserId = user!.id;
      });

      _loadPlayers(code);
      _subscribeToLobby();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Erstellen: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Join via QR scan ──────────────────────────────────────────────────────

  void _onQrDetected(BarcodeCapture capture) {
    if (_isScanning) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final raw = barcode.rawValue ?? '';
    String? code;
    if (raw.startsWith('$_scheme://join/')) {
      code = raw.substring('$_scheme://join/'.length);
    } else if (RegExp(r'^\d{4}$').hasMatch(raw)) {
      code = raw;
    }

    if (code != null) {
      setState(() => _isScanning = false);
      _joinTable(code);
    }
  }

  Future<void> _joinTable(String code) async {
    setState(() => _isLoading = true);

    try {
      var user = _supabase.auth.currentUser;

      if (user == null) {
        final anonResult = await _supabase.auth.signInAnonymously();
        user = anonResult.user;
      }

      final username = _usernameController.text.trim().isNotEmpty
          ? _usernameController.text.trim()
          : 'Gast_${Random().nextInt(9999)}';

      await _supabase.from('profiles').upsert({
        'id': user!.id,
        'username': username,
      });

      // Check table exists
      final table = await _supabase
          .from('tables')
          .select('id, status')
          .eq('id', code)
          .maybeSingle();

      if (table == null) throw Exception('Tisch nicht gefunden');
      if (table['status'] != 'lobby') {
        throw Exception('Tisch ist nicht in der Lobby');
      }

      // Find free seat
      final existing = await _supabase
          .from('table_players')
          .select('seat_index')
          .eq('table_id', code);
      final takenSeats = (existing as List)
          .map<int>((p) => p['seat_index'] as int)
          .toSet();
      int seatIndex = 0;
      for (int i = 0; i < 4; i++) {
        if (!takenSeats.contains(i)) {
          seatIndex = i;
          break;
        }
      }

      await _supabase.from('table_players').insert({
        'table_id': code,
        'player_id': user.id,
        'seat_index': seatIndex,
        'is_ready': false,
      });

      setState(() {
        _joinedTableId = code;
        _isLoading = false;
        _localUserId = user!.id;
      });

      _loadPlayers(code);
      _subscribeToLobby();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Beitritt fehlgeschlagen: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleReady() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final myPlayer = _players.firstWhere(
      (p) => p['player_id'] == user.id,
      orElse: () => {},
    );
    final currentReady = myPlayer['is_ready'] as bool? ?? false;

    await _supabase
        .from('table_players')
        .update({'is_ready': !currentReady})
        .eq('player_id', user.id)
        .eq('table_id', _hostedTableId ?? _joinedTableId!);

    _loadPlayers(_hostedTableId ?? _joinedTableId!);
  }

  void _navigateToRound(String tableId) {
    // Navigate to Gosterge selection first, then ActiveRoundScreen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GostergeScreen(
          tableId: tableId,
          roundNumber: 1,
        ),
      ),
    );
  }

  String _generateCode() {
    final rng = Random();
    return List.generate(_tableCodeLength, (_) => rng.nextInt(10)).join();
  }

  String get _currentTableId => _hostedTableId ?? _joinedTableId ?? '';
  String get _joinUrl => '$_scheme://join/$_currentTableId';

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('RenkliOkeyScout',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF58A6FF)))
          : _isScanning
              ? _buildScanner()
              : _hostedTableId != null || _joinedTableId != null
                  ? _buildLobby()
                  : _buildEntry(),
    );
  }

  Widget _buildEntry() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _usernameField(),
          const SizedBox(height: 32),
          _buildHostButton(),
          const SizedBox(height: 16),
          _buildJoinButton(),
        ],
      ),
    );
  }

  Widget _usernameField() {
    return TextField(
      controller: _usernameController,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Dein Spielername',
        labelStyle: TextStyle(color: Color(0xFF8B949E)),
        prefixIcon: Icon(Icons.person, color: Color(0xFF8B949E)),
      ),
    );
  }

  Widget _buildHostButton() {
    return ElevatedButton.icon(
      onPressed: _hostTable,
      icon: const Icon(Icons.add_circle_outline),
      label: const Text('Tisch erstellen'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF238636),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildJoinButton() {
    return ElevatedButton.icon(
      onPressed: () => setState(() => _isScanning = true),
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text('QR-Code scannen'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1F6FEB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: _onQrDetected,
        ),
        Positioned(
          top: 16,
          left: 16,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => _isScanning = false),
          ),
        ),
        const Center(
          child: Text(
            'QR-Code scannen',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildLobby() {
    return Column(
      children: [
        // QR + Share
        Container(
          padding: const EdgeInsets.all(24),
          color: const Color(0xFF161B22),
          child: Column(
            children: [
              const Text('Tisch-Code',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                _currentTableId,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 16),
              QrImageView(
                data: _joinUrl,
                size: 180,
                backgroundColor: Colors.white,
                version: QrVersions.auto,
              ),
              const SizedBox(height: 8),
              Text(_joinUrl,
                  style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _players.isEmpty
              ? const Center(
                  child: Text('Warte auf Spieler...',
                      style: TextStyle(color: Color(0xFF8B949E))))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _players.length,
                  itemBuilder: (ctx, i) => _playerCard(_players[i]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _isHost ? _buildStartButton() : _buildReadyButton(),
        ),
      ],
    );
  }

  Widget _playerCard(Map<String, dynamic> player) {
    final isReady = player['is_ready'] as bool? ?? false;
    final isCreator = player['is_creator'] as bool? ?? false;
    final username = player['profiles']?['username'] ?? 'Unbekannt';
    final seatIndex = (player['seat_index'] as int? ?? 0) + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isReady ? const Color(0xFF238636) : const Color(0xFF30363D),
          width: isReady ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF21262D),
            child: Text('$seatIndex',
                style: const TextStyle(color: Color(0xFF58A6FF))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(username,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    if (isCreator) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star, color: Color(0xFFF0C000), size: 14),
                    ],
                  ],
                ),
                if (isCreator)
                  const Text('Gastgeber',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
              ],
            ),
          ),
          Icon(isReady ? Icons.check_circle : Icons.hourglass_empty,
              color: isReady ? const Color(0xFF238636) : const Color(0xFF8B949E),
              size: 22),
        ],
      ),
    );
  }

  Widget _buildReadyButton() {
    final myPlayer = _players.firstWhere(
      (p) => p['player_id'] == _localUserId,
      orElse: () => {'is_ready': false},
    );
    final isReady = myPlayer['is_ready'] as bool? ?? false;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _toggleReady,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isReady ? const Color(0xFF21262D) : const Color(0xFF238636),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(isReady ? 'Bereit ✓' : 'Bereit melden'),
      ),
    );
  }

  Widget _buildStartButton() {
    final allReady = _players.isNotEmpty &&
        _players.every((p) => p['is_ready'] == true);
    final hasEnoughPlayers = _players.length >= 2;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: hasEnoughPlayers && allReady ? _startGame : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              hasEnoughPlayers && allReady
                  ? const Color(0xFF238636)
                  : const Color(0xFF21262D),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          hasEnoughPlayers && allReady
              ? 'Spiel starten'
              : '${_players.length}/4 Spieler bereit',
        ),
      ),
    );
  }

  Future<void> _startGame() async {
    await _supabase
        .from('tables')
        .update({'status': 'playing'})
        .eq('id', _currentTableId);
    _navigateToRound(_currentTableId);
  }

  @override
  void dispose() {
    _lobbyChannel?.unsubscribe();
    _usernameController.dispose();
    super.dispose();
  }
}
