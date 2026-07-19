// lib/services/vision_service.dart
// RenkliOkeyScout — Vision AI Service (on-device TFLite + M90q proxy + Manual)
//
// APP IS FULLY INDEPENDENT — Manual mode always works, no server/network required.
//
// Priority order:
//   1. TFLite on-device  (trained model bundled in assets)     ← future
//   2. M90q Ollama proxy  (httpProxyUrl, local WLAN only)     ← optional
//   3. Manual mode        (user enters basis points directly) ← ALWAYS works
//
// The app is designed to work 100% without M90q or any server.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../utils/score_calculator.dart';

// ─── Result type ─────────────────────────────────────────────────────────────

class VisionResult {
  final List<Tile> penaltyTiles;
  final String rawResponse;
  final double confidence;
  /// Which mode produced this result: 'tflite' | 'proxy' | 'manual'
  final String mode;

  const VisionResult({
    required this.penaltyTiles,
    required this.rawResponse,
    required this.confidence,
    this.mode = 'manual',
  });
}

// ─── Main service ─────────────────────────────────────────────────────────────

/// Unified vision service — tries TFLite first, then M90q proxy,
/// falls back to manual (no network/server ever required).
class VisionService {
  /// Path to bundled TFLite model (assets/okey_tiles.tflite).
  /// Set automatically when model is trained and bundled.
  final String? tfliteModelPath;

  /// Ollama vision proxy on M90q, e.g. 'http://192.168.178.187:5000/analyse'.
  /// Only used when phone is on the same local WLAN as M90q.
  /// Null = skip proxy, go straight to manual mode.
  final String? httpProxyUrl;

  final http.Client _http;

  VisionService({
    this.tfliteModelPath,
    this.httpProxyUrl,
    http.Client? client,
  }) : _http = client ?? http.Client();

  /// Analyse a rack photo and return penalty tiles.
  ///
  /// Priority: TFLite → M90q proxy → Manual mode (user enters count directly).
  /// Manual mode NEVER fails and needs no network.
  Future<VisionResult> analyseRack({
    required String imagePath,
    required Tile gosterge,
    /// For manual mode: pre-filled basis points (e.g. from a previous run).
    int? manualBasisPunkte,
  }) async {
    // 1. TFLite on-device (future)
    if (tfliteModelPath != null) {
      try {
        return await _tfliteAnalyse(imagePath, gosterge);
      } catch (_) {
        // Fall through
      }
    }

    // 2. M90q Ollama proxy (only if URL configured and reachable)
    if (httpProxyUrl != null) {
      try {
        return await _httpAnalyse(imagePath, gosterge);
      } catch (_) {
        // Fall through to manual
      }
    }

    // 3. Manual mode — always works, no network, no server
    return _manualMode(manualBasisPunkte);
  }

  /// MANUAL MODE: user enters basis points directly.
  /// Returns a VisionResult with the manually entered tiles.
  /// confidence = 1.0 because it's directly from the user.
  VisionResult _manualMode(int? basisPunkte) {
    final count = basisPunkte ?? 0;
    final tiles = <Tile>[];
    for (int i = 0; i < count; i++) {
      // Placeholder tiles — user sees them and can correct
      tiles.add(Tile(TileColor.yellow, 1, false));
    }
    return VisionResult(
      penaltyTiles: tiles,
      rawResponse: 'Manuelle Eingabe ($count Steine)',
      confidence: 1.0,
      mode: 'manual',
    );
  }

  // ─── TFLite on-device ────────────────────────────────────────────────────
  Future<VisionResult> _tfliteAnalyse(String imagePath, Tile gosterge) async {
    // TODO(phase2): implement with tflite_flutter + bundled okey_tiles.tflite
    //   final interpreter = await Interpreter.fromAsset('assets/okey_tiles.tflite');
    //   interpreter.run(imagePath, output);
    throw UnimplementedError('TFLite model not yet bundled — see assets/');
  }

  // ─── M90q Ollama proxy ───────────────────────────────────────────────────
  Future<VisionResult> _httpAnalyse(String imagePath, Tile gosterge) async {
    final uri = Uri.parse('$httpProxyUrl/analyse');
    final file = File(imagePath);
    if (!await file.exists()) {
      throw VisionException('Image file not found: $imagePath');
    }

    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', imagePath))
      ..fields['gosterge_color'] = gosterge.color.name
      ..fields['gosterge_number'] = gosterge.number.toString();

    final streamed = await _http
        .send(request)
        .timeout(const Duration(seconds: 30));

    if (streamed.statusCode == 502 || streamed.statusCode == 503) {
      // Proxy unreachable or Ollama overloaded — go manual without error
      return _manualMode(null);
    }

    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw VisionException('Proxy ${response.statusCode}');
    }

    return _parseJsonResponse(response.body);
  }

  VisionResult _parseJsonResponse(String body) {
    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return _manualMode(null);
    }

    final confidence = (parsed['confidence'] as num?)?.toDouble() ?? 0.0;
    final rawResponse = parsed['reasoning'] as String? ?? '';
    final tiles = <Tile>[];

    final rawTiles = parsed['penalty_tiles'] as List<dynamic>? ?? [];
    for (final t in rawTiles) {
      final m = t as Map<String, dynamic>;
      final colorStr = (m['color'] as String? ?? 'yellow').toLowerCase();
      final number = (m['number'] as num?)?.toInt() ?? 1;
      final isFalse = (m['is_false_okey'] as bool?) ?? false;

      TileColor color;
      switch (colorStr) {
        case 'blue':  color = TileColor.blue;   break;
        case 'red':   color = TileColor.red;    break;
        case 'black': color = TileColor.black;   break;
        default:      color = TileColor.yellow;
      }
      tiles.add(Tile(color, number, isFalse));
    }

    return VisionResult(
      penaltyTiles: tiles,
      rawResponse: rawResponse,
      confidence: confidence,
      mode: 'proxy',
    );
  }

  void dispose() => _http.close();
}

// ─── Error type ──────────────────────────────────────────────────────────────

class VisionException implements Exception {
  final String message;
  const VisionException(this.message);
  @override String toString() => 'VisionException: $message';
}
