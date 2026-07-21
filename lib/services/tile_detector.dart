// lib/services/tile_detector.dart
//
// STUB implementation — used when onnxruntime is NOT in pubspec.yaml.
// VisionService falls back to Manual mode.
//
// To enable ONNX tile detection:
//   1. Uncomment onnxruntime in pubspec.yaml
//   2. In vision_service.dart: change the import to 'tile_detector_impl.dart'

import 'dart:io';

/// A detected tile (stub — minimal API matching the real DetectedTile).
class DetectedTile {
  final double x, y, w, h;
  final double confidence;
  final bool isJoker;

  const DetectedTile({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.confidence,
    required this.isJoker,
  });
}

/// Result of scanning a photo (stub).
class ScanResult {
  final List<DetectedTile> tiles;
  final Duration inferenceTime;
  final bool modelLoaded;

  const ScanResult({
    required this.tiles,
    required this.inferenceTime,
    required this.modelLoaded,
  });
}

/// TileDetector stub — ONNX not available, falls back to manual.
class TileDetector {
  bool get isModelLoaded => false;

  Future<void> load() async {}

  Future<ScanResult> detect(File imageFile) async {
    return const ScanResult(
      tiles: [],
      inferenceTime: Duration.zero,
      modelLoaded: false,
    );
  }

  void dispose() {}
}
