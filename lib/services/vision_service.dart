// lib/services/vision_service.dart
// RenkliOkeyScout — Vision AI Service (on-device ONNX + M90q proxy + Manual)
//
// APP IS FULLY INDEPENDENT — Manual mode always works, no server/network required.
//
// Priority order:
//   1. ONNX on-device  (YOLO detector + ColorNumber classifier)  ← NOW
//   2. M90q Ollama proxy (httpProxyUrl, local WLAN only)        ← optional
//   3. Manual mode      (user enters basis points directly)      ← ALWAYS works
//
// ONNX model: assets/models/okey_yolo_best.onnx
//   Input:  [1, 3, 224, 224]  (RGB, 224×224)
//   Output: [1, 6, 1029]       (6 classes × 1029 slots)
//   Classes: 0=tile, 1=joker, 2-5=undefined

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../utils/score_calculator.dart';
import 'tile_detector.dart';
import 'tile_classifier.dart';

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

/// Unified vision service — tries ONNX first, then M90q proxy,
/// falls back to manual (no network/server ever required).
class VisionService {
  final TileDetector _detector;
  final TileClassifier _classifier;
  bool _onnxLoaded = false;

  /// Ollama vision proxy on M90q, e.g. 'http://192.168.178.187:5000/analyse'.
  /// Only used when phone is on the same local WLAN as M90q.
  /// Null = skip proxy, go straight to manual mode.
  final String? httpProxyUrl;

  final http.Client _http;

  VisionService({
    this.httpProxyUrl,
    http.Client? client,
  })  : _detector = TileDetector(),
        _classifier = TileClassifier(),
        _http = client ?? http.Client();

  /// Load the ONNX model. Call once at app start.
  Future<void> loadModel() async {
    if (_onnxLoaded) return;
    await _detector.load();
    _onnxLoaded = true;
  }

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
    // 1. ONNX on-device (YOLO detector + ColorNumber classifier)
    if (!_onnxLoaded) {
      await loadModel();
    }
    if (_onnxLoaded && _detector.isModelLoaded) {
      try {
        return await _onnxAnalyse(imagePath, gosterge);
      } catch (_) {
        // Fall through to next option
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

  // ─── ONNX on-device ────────────────────────────────────────────────────

  /// Two-stage ONNX pipeline:
  ///   1. YOLO detector → bounding boxes of tiles
  ///   2. ColorNumber classifier → color + number per tile
  Future<VisionResult> _onnxAnalyse(String imagePath, Tile gosterge) async {
    final sw = Stopwatch()..start();

    // Stage 1: Detect tiles
    final scanResult = await _detector.detect(File(imagePath));
    if (scanResult.tiles.isEmpty) {
      return _manualMode(null);
    }

    // Stage 2: Classify each tile (color + number)
    final classifiedTiles = await _classifyTiles(File(imagePath), scanResult.tiles);

    // Convert to Tile objects
    final tiles = classifiedTiles.map((ct) {
      // If classifier says unknown, default to a penalty tile
      final color = ct.color == ClassifierColor.unknown
          ? TileColor.yellow
          : TileColor.values.firstWhere(
              (c) => c.name == ct.colorName,
              orElse: () => TileColor.yellow,
            );
      // Joker tiles are gösterge+1, not penalty tiles — skip
      return Tile(color, ct.number, ct.isJoker);
    }).toList();

    sw.stop();
    final avgConf = classifiedTiles.isEmpty
        ? 0.0
        : classifiedTiles.map((t) => t.confidence).reduce((a, b) => a + b) /
            classifiedTiles.length;

    return VisionResult(
      penaltyTiles: tiles,
      rawResponse:
          '${tiles.length} Steine erkannt (${sw.elapsed.inMilliseconds}ms, ${scanResult.tiles.length} Detections)',
      confidence: avgConf,
      mode: 'onnx',
    );
  }

  /// Classify each detected tile: crop → color + number + joker.
  Future<List<ClassifiedTile>> _classifyTiles(
      File imageFile, List<DetectedTile> detections) async {
    final results = <ClassifiedTile>[];
    for (final det in detections) {
      // Crop the tile from the image
      final cropped = await _cropTile(imageFile, det);
      if (cropped != null) {
        final classified = await _classifier.classify(cropped);
        results.add(classified);
      }
    }
    return results;
  }

  /// Crop a tile region from the image file.
  Future<File?> _cropTile(File imageFile, DetectedTile det) async {
    try {
      // For now, return the original file — the classifier handles the full image
      // A proper implementation would crop to det.x,y,w,h and save to temp file
      // TODO: implement proper crop using image package
      return imageFile;
    } catch (e) {
      return null;
    }
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

  void dispose() {
    _detector.dispose();
    _http.close();
  }
}

// ─── Error type ──────────────────────────────────────────────────────────────

class VisionException implements Exception {
  final String message;
  const VisionException(this.message);
  @override String toString() => 'VisionException: $message';
}
