// lib/services/tile_classifier.dart
// RenkliOkeyScout — Color + Number classifier for cropped tile images
//
// Two-stage architecture:
//   Stage 1 (heuristic): Dominant color detection → Gelb/Blau/Rot/Schwarz
//   Stage 2 (placeholder): Number pattern matching → 1..13
//   → When real classifier model is ready, swap _classifyColor and _classifyNumber
//
// Future: Replace with a trained CNN classifier (color_number_model.onnx)
//         Input: [1, 3, 64, 64] cropped tile
//         Output: [1, 54]  (54 classes: yellow_1..black_13)

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

enum ClassifierColor { yellow, blue, red, black, unknown }

class ClassifiedTile {
  final ClassifierColor color;
  final int number;
  final double confidence;
  final bool isJoker;

  const ClassifiedTile({
    required this.color,
    required this.number,
    required this.confidence,
    required this.isJoker,
  });

  String get colorName {
    switch (color) {
      case ClassifierColor.yellow:
        return 'yellow';
      case ClassifierColor.blue:
        return 'blue';
      case ClassifierColor.red:
        return 'red';
      case ClassifierColor.black:
        return 'black';
      case ClassifierColor.unknown:
        return 'unknown';
    }
  }
}

class TileClassifier {
  /// Classify a cropped tile image.
  /// Returns a ClassifiedTile with color + number + joker flag.
  Future<ClassifiedTile> classify(File tileImage) async {
    try {
      final pixels = await _loadPixels(tileImage);
      if (pixels == null) {
        return const ClassifiedTile(
          color: ClassifierColor.unknown,
          number: 1,
          confidence: 0.0,
          isJoker: false,
        );
      }

      // 1. Detect if it's the joker (red joker tile — has star/pattern)
      final isJoker = _detectJokerPattern(pixels);

      // 2. Classify color
      final colorResult = await _classifyColor(pixels);

      // 3. Classify number (heuristic — will be ML model later)
      final numberResult = await _classifyNumber(pixels);

      return ClassifiedTile(
        color: colorResult.value,
        number: numberResult.value,
        confidence: (colorResult.confidence + numberResult.confidence) / 2,
        isJoker: isJoker,
      );
    } catch (e) {
      debugPrint('[TileClassifier] Error: $e');
      return const ClassifiedTile(
        color: ClassifierColor.unknown,
        number: 1,
        confidence: 0.0,
        isJoker: false,
      );
    }
  }

  // ─── Color Classification ─────────────────────────────────────────────────

  Future<_Result<ClassifierColor>> _classifyColor(List<int> pixels) async {
    if (pixels.isEmpty) return _Result(ClassifierColor.unknown, 0.0);

    // Okey tile color ranges (approximate, from real images):
    // Yellow:  R~230-255, G~200-230, B~0-30
    // Blue:    R~0-30,    G~100-150, B~200-255
    // Red:     R~220-255, G~0-50,    B~0-30
    // Black:   R~30-80,   G~30-80,   B~30-80

    int rSum = 0, gSum = 0, bSum = 0;
    int count = 0;
    final step = (pixels.length / 3000).ceil(); // sample ~3000 pixels for speed
    for (int i = 0; i < pixels.length - 3; i += step * 4) {
      rSum += pixels[i];
      gSum += pixels[i + 1];
      bSum += pixels[i + 2];
      count++;
    }
    if (count == 0) return _Result(ClassifierColor.unknown, 0.0);

    final rAvg = rSum ~/ count;
    final gAvg = gSum ~/ count;
    final bAvg = bSum ~/ count;

    // Score each color
    final yellowScore = _colorScore(rAvg, gAvg, bAvg, 240, 215, 20);
    final blueScore = _colorScore(rAvg, gAvg, bAvg, 15, 125, 235);
    final redScore = _colorScore(rAvg, gAvg, bAvg, 240, 25, 15);
    final blackScore = _colorScore(rAvg, gAvg, bAvg, 55, 55, 55);

    final scores = [
      (ClassifierColor.yellow, yellowScore),
      (ClassifierColor.blue, blueScore),
      (ClassifierColor.red, redScore),
      (ClassifierColor.black, blackScore),
    ];
    scores.sort((a, b) => b.$2.compareTo(a.$2));

    // Confidence: how much the best beats the second best
    final best = scores[0].$2;
    final second = scores[1].$2;
    final confidence = best > 0 ? (best - second) / best * 0.7 + 0.3 : 0.3;

    return _Result(scores[0].$1, confidence.clamp(0.0, 1.0));
  }

  double _colorScore(int r, int g, int b, int tr, int tg, int tb) {
    final dr = (r - tr).abs();
    final dg = (g - tg).abs();
    final db = (b - tb).abs();
    return 1.0 / (1.0 + (dr + dg + db) / 100.0);
  }

  // ─── Number Classification (heuristic placeholder) ──────────────────────

  Future<_Result<int>> _classifyNumber(List<int> pixels) async {
    // Placeholder: returns a random number 1-13
    // TODO: Replace with a trained CNN classifier
    // For now, try simple heuristics based on edge density
    // Real implementation will use the color_number_model.onnx
    await Future.delayed(const Duration(milliseconds: 5));

    // Simple heuristic: count vertical edges (lines on tiles = numbers)
    // Higher edge density → larger numbers
    int edgeSum = 0;
    final step = (pixels.length / 1000).ceil();
    for (int i = 4; i < pixels.length - 4; i += step * 4) {
      // Sobel-like: compare with neighbor
      final diff = (pixels[i] - pixels[i - 4]).abs();
      edgeSum += diff;
    }
    final avgEdge = edgeSum ~/ (pixels.length ~/ step);

    // Map edge density to number range
    // Low edges (smooth) → 1,8 (simple shapes)
    // High edges (many lines) → 2-7, 9-13 (complex)
    int number;
    if (avgEdge < 8) {
      number = [1, 8][DateTime.now().millisecond % 2];
    } else if (avgEdge < 20) {
      number = 2 + (DateTime.now().millisecond % 6); // 2-7
    } else if (avgEdge < 40) {
      number = 9 + (DateTime.now().millisecond % 5); // 9-13
    } else {
      number = 3 + (DateTime.now().millisecond % 11); // 3-13
    }

    return _Result(number.clamp(1, 13), 0.3); // low confidence = heuristic
  }

  // ─── Joker Detection ────────────────────────────────────────────────────

  bool _detectJokerPattern(List<int> pixels) {
    // Joker tiles have a distinctive star/asterisk pattern in red
    // Check for red saturation + specific texture
    if (pixels.isEmpty) return false;

    int redSum = 0, satSum = 0, count = 0;
    final step = (pixels.length / 2000).ceil();
    for (int i = 0; i < pixels.length - 3; i += step * 4) {
      final r = pixels[i];
      final g = pixels[i + 1];
      final b = pixels[i + 2];
      redSum += r;
      satSum += (r - g).abs() + (r - b).abs();
      count++;
    }
    if (count == 0) return false;

    final redAvg = redSum ~/ count;
    final satAvg = satSum ~/ count;

    // Joker: very red + high saturation
    return redAvg > 180 && satAvg > 80;
  }

  // ─── Pixel Loading ──────────────────────────────────────────────────────

  Future<List<int>?> _loadPixels(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;

      final pixels = <int>[];
      final byteData =
          await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final data = byteData.buffer.asUint8List();
      for (int i = 0; i < data.length; i += 4) {
        pixels.addAll([data[i], data[i + 1], data[i + 2]]); // R, G, B
      }
      return pixels;
    } catch (e) {
      debugPrint('[TileClassifier] Pixel load error: $e');
      return null;
    }
  }

  ClassifiedTile _unknown() => const ClassifiedTile(
        color: ClassifierColor.unknown,
        number: 1,
        confidence: 0.0,
        isJoker: false,
      );
}

class _Result<T> {
  final T value;
  final double confidence;
  const _Result(this.value, this.confidence);
}
