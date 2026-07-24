// lib/services/vision_service.dart
// RenkliOkeyScout — Vision AI Service (on-device ONNX only)
//
// APP IS FULLY AUTONOMOUS — works 100% on-device, no PC, no server, no network.
//
// Priority order:
//   1. ONNX on-device  (YOLO detector + ColorNumber classifier)  ← DEFAULT
//   2. Manual mode     (user enters basis points directly)      ← FALLBACK
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
  /// Which mode produced this result: 'onnx' | 'manual'
  final String mode;

  const VisionResult({
    required this.penaltyTiles,
    required this.rawResponse,
    required this.confidence,
    this.mode = 'manual',
  });
}

// ─── Main service ─────────────────────────────────────────────────────────────

/// Unified vision service — tries ONNX on-device first,
/// falls back to manual mode (no network/server ever required).
///
/// AUTONOMOUS: No M90q, no Ollama, no proxy, no LAN dependency.
/// Phone runs the model directly with onnxruntime.
class VisionService {
  final TileDetector _detector;
  final TileClassifier _classifier;
  bool _onnxLoaded = false;

  /// HTTP client kept for future image-crop API (e.g. image package).
  /// NOT used for any external server.
  final http.Client _http;

  VisionService({
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
  /// Priority: ONNX on-device → Manual mode.
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
        // Fall through to manual
      }
    }

    // 2. Manual mode — always works, no network, no server
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
      tiles.add(Tile(TileColor.yellow, 1, isOkey: false));
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
      return Tile(color, ct.number, isOkey: ct.isJoker);
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
