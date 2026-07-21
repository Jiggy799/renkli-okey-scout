// lib/services/tile_detector_impl.dart
// ONNX implementation — loaded only when onnxruntime is in pubspec.yaml.
//
// API reference (onnxruntime ^1.4.1):
//   OrtEnv.instance.init()
//   OrtSession.fromBuffer(bytes, options)     ← sync
//   session.run(runOptions, inputs)           ← sync
//   OrtValueTensor.createTensorWithDataList(data, shape)

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

/// A detected tile with bounding box.
class DetectedTile {
  final double x, y, w, h; // normalised 0..1
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

/// Result of scanning a photo.
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

class TileDetector {
  OrtSession? _session;
  bool _isLoading = false;
  bool _loadFailed = false;

  static const int _inputH = 224;
  static const int _inputW = 224;
  static const double _confThresh = 0.35;
  static const double _iouThresh = 0.45;

  bool get isModelLoaded => _session != null && !_loadFailed;

  Future<void> load() async {
    if (_session != null || _isLoading || _loadFailed) return;
    _isLoading = true;
    try {
      // Initialize ONNX Runtime environment
      OrtEnv.instance.init();

      final sessionOptions = OrtSessionOptions();
      sessionOptions.setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortEnableAll,
      );

      final modelData =
          await rootBundle.load('assets/models/okey_yolo_best.onnx');
      final bytes = modelData.buffer.asUint8List();

      _session = OrtSession.fromBuffer(bytes, sessionOptions);

      debugPrint('[TileDetector] Model loaded OK');
    } catch (e, st) {
      debugPrint('[TileDetector] Load failed: $e\n$st');
      _loadFailed = true;
    } finally {
      _isLoading = false;
    }
  }

  Future<ScanResult> detect(File imageFile) async {
    final sw = Stopwatch()..start();
    if (_session == null) {
      return ScanResult(
        tiles: [],
        inferenceTime: Duration.zero,
        modelLoaded: false,
      );
    }

    try {
      // Preprocess image to [1, 3, 224, 224] float32 tensor
      final inputTensor = await _preprocess(imageFile);

      // Run inference — synchronous
      final runOptions = OrtRunOptions();
      final inputs = {'images': inputTensor};
      final outputs = _session!.run(runOptions, inputs);
      runOptions.release();

      // Parse output [1, 6, 1029] → list of DetectedTile
      final outputValue = outputs[0];
      final outputData = outputValue!.value as List;
      final tileList = _parseOutput(outputData);

      inputTensor.release();
      for (final o in outputs) {
        o?.release();
      }

      sw.stop();
      return ScanResult(
        tiles: tileList,
        inferenceTime: sw.elapsed,
        modelLoaded: true,
      );
    } catch (e) {
      debugPrint('[TileDetector] Inference error: $e');
      sw.stop();
      return ScanResult(
        tiles: [],
        inferenceTime: sw.elapsed,
        modelLoaded: true,
      );
    }
  }

  Future<OrtValueTensor> _preprocess(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    final byteData =
        await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception('Failed to decode image');
    final pixelData = byteData.buffer.asUint8List();

    // Build CHW tensor (YOLO expects CHW input)
    final buffer = Float32List(3 * _inputH * _inputW);

    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < _inputH; y++) {
        for (int x = 0; x < _inputW; x++) {
          final srcX =
              (x / _inputW * img.width).round().clamp(0, img.width - 1);
          final srcY =
              (y / _inputH * img.height).round().clamp(0, img.height - 1);
          final pi = (srcY * img.width + srcX) * 4;
          double val;
          if (c == 0) {
            val = pixelData[pi].toDouble();       // B
          } else if (c == 1) {
            val = pixelData[pi + 1].toDouble();   // G
          } else {
            val = pixelData[pi + 2].toDouble();   // R
          }
          // YOLO standard: normalise to -1..1
          buffer[c * _inputH * _inputW + y * _inputW + x] = (val / 127.5) - 1.0;
        }
      }
    }

    final shape = [1, 3, _inputH, _inputW];
    return OrtValueTensor.createTensorWithDataList(buffer, shape);
  }

  List<DetectedTile> _parseOutput(dynamic outputData) {
    // outputData is a nested list: [[[x0..x1029], [y0..y1029], [w0..w1029],
    //                                  [h0..h1029], [c00..c01028], [c10..c11028]]]
    // 6 rows × 1029 columns
    if (outputData is! List || outputData.isEmpty) return [];
    final rows = outputData as List;
    if (rows.length < 6) return [];

    final numSlots = (rows[0] as List).length;
    final detections = <DetectedTile>[];

    for (int slot = 0; slot < numSlots; slot++) {
      final x = (rows[0] as List)[slot] as double;
      final y = (rows[1] as List)[slot] as double;
      final w = (rows[2] as List)[slot] as double;
      final h = (rows[3] as List)[slot] as double;
      final class0 = (rows[4] as List)[slot] as double;
      final class1 = (rows[5] as List)[slot] as double;

      final maxScore = max(class0, class1);
      if (maxScore < _confThresh) continue;

      final isJoker = class1 > class0;

      detections.add(DetectedTile(
        x: x.clamp(0.0, 1.0),
        y: y.clamp(0.0, 1.0),
        w: w.clamp(0.0, 1.0),
        h: h.clamp(0.0, 1.0),
        confidence: maxScore,
        isJoker: isJoker,
      ));
    }

    return _nms(detections);
  }

  List<DetectedTile> _nms(List<DetectedTile> boxes) {
    if (boxes.isEmpty) return [];
    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));
    final keep = <DetectedTile>[];
    final suppressed = List<bool>.filled(boxes.length, false);

    for (int i = 0; i < boxes.length; i++) {
      if (suppressed[i]) continue;
      keep.add(boxes[i]);
      for (int j = i + 1; j < boxes.length; j++) {
        if (suppressed[j]) continue;
        if (_iou(boxes[i], boxes[j]) > _iouThresh) suppressed[j] = true;
      }
    }
    return keep;
  }

  double _iou(DetectedTile a, DetectedTile b) {
    final x1 = max(a.x, b.x);
    final y1 = max(a.y, b.y);
    final x2 = min(a.x + a.w, b.x + b.w);
    final y2 = min(a.y + a.h, b.y + b.h);
    if (x2 <= x1 || y2 <= y1) return 0.0;
    final inter = (x2 - x1) * (y2 - y1);
    return inter / (a.w * a.h + b.w * b.h - inter);
  }

  void dispose() {
    _session?.release();
    _session = null;
    try {
      OrtEnv.instance.release();
    } catch (_) {}
  }
}
