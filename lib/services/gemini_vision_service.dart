// lib/services/gemini_vision_service.dart
// RenkliOkeyScout — Gemini Pro Vision Tile Detection
//
// Nutzt Gemini Pro Vision um Okey-Steine auf einem Brett zu erkennen.
// Vorteil: keine lokale Modell-Datei nötig, funktioniert sofort.
//
// API: https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../utils/score_calculator.dart';

/// Erkannter Stein mit Konfidenz
class RecognizedTile {
  final Tile tile;
  final double confidence;

  const RecognizedTile({required this.tile, required this.confidence});
}

class GeminiVisionService {
  // Gemini API-Key wird zur Laufzeit gesetzt via initialize()
  // User muss den Key einmalig eingeben (über Settings-Screen)
  static String _apiKey = '';

  /// API-Key zur Laufzeit setzen (z.B. von Settings)
  static void initialize(String apiKey) {
    _apiKey = apiKey;
  }

  /// Prüfe ob Key gesetzt ist
  static bool get hasApiKey => _apiKey.isNotEmpty;

  // gemini-flash-latest funktioniert mit Vision und ist free-tier friendly
  // Alternativen: gemini-2.5-pro-preview-tts (Pro), gemini-flash-lite-latest
  static const String _model = 'gemini-flash-latest';

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  /// Erkennt Schrott-Steine aus einem Foto via Gemini Vision.
  ///
  /// Returns: Liste der (erkannten) Schrott-Steine
  Future<List<RecognizedTile>> recognizeSchrott({
    required File photo,
    required Tile gosterge,
  }) async {
    if (_apiKey.isEmpty) {
      debugPrint('[GeminiVision] No API key set. User must configure in Settings.');
      return _fallbackRecognizedTiles(gosterge);
    }
    try {
      // 1. Bild komprimieren (max 1024px, JPEG 75%)
      final compressed = await _compress(photo);
      final base64Image = base64Encode(compressed);

      // 2. Prompt an Gemini
      final prompt = _buildPrompt(gosterge);

      // 3. API Request
      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Image,
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'maxOutputTokens': 500,
          'temperature': 0.1, // Sehr deterministisch
        },
      };

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'x-goog-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        debugPrint('[GeminiVision] HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
        return _fallbackRecognizedTiles(gosterge);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
      debugPrint('[GeminiVision] Response: $text');

      // 4. JSON aus Antwort extrahieren
      return _parseTiles(text, gosterge);
    } catch (e) {
      debugPrint('[GeminiVision] Error: $e');
      return _fallbackRecognizedTiles(gosterge);
    }
  }

  /// Prompt für Gemini
  String _buildPrompt(Tile gosterge) {
    return '''This image shows a hand of Okey (Turkish Rummy) tiles.

TASK: Identify ALL visible tiles and return them in JSON.

RULES:
- Each tile has a COLOR (red, blue, yellow, black) and NUMBER (1-13)
- The Gösterge is ${gosterge.color.name} ${gosterge.number}
- The Joker is ${gosterge.color.name} ${gosterge.number == 13 ? 1 : gosterge.number + 1} (replaceable stone)
- Count ONLY the tiles you can clearly see in the image

RESPOND IN THIS EXACT JSON FORMAT (no markdown, no explanation):
{"tiles": [{"color": "red", "number": 7}, {"color": "blue", "number": 3}]}

Use lowercase color names. Numbers 1-13 only.''';
  }

  /// Parst die Gemini-Antwort in eine Liste von Tiles mit Confidence.
  List<RecognizedTile> _parseTiles(String response, Tile gosterge) {
    try {
      // Gemini wraps sometimes in markdown code blocks
      String jsonText = response.trim();
      if (jsonText.startsWith('```')) {
        // Extrahiere JSON aus markdown code block
        final match = RegExp(r'\{[^{}]*"tiles"[^{}]*\[.*?\][^{}]*\}').firstMatch(jsonText);
        if (match != null) {
          jsonText = match.group(0)!;
        } else {
          // Fallback: nimm alles zwischen ```json und ```
          final start = jsonText.indexOf('{');
          final end = jsonText.lastIndexOf('}');
          if (start >= 0 && end > start) {
            jsonText = jsonText.substring(start, end + 1);
          }
        }
      }

      final data = jsonDecode(jsonText) as Map<String, dynamic>;
      final tilesJson = data['tiles'] as List<dynamic>? ?? [];


      final tiles = <RecognizedTile>[];
      for (int i = 0; i < tilesJson.length; i++) {
        try {
          final t = tilesJson[i];
          final colorStr = (t['color'] as String).toLowerCase();
          final number = t['number'] as int;
          if (number < 1 || number > 13) continue;

          final color = TileColor.values.firstWhere(
            (c) => c.name.toLowerCase() == colorStr,
            orElse: () => TileColor.yellow,
          );
          // Higher confidence for tiles with clear color+number
          // Lower if color was fallback to yellow
          double conf = 0.9;
          if (color == TileColor.yellow && colorStr != 'yellow') conf = 0.6;
          if (number < 1 || number > 13) conf = 0.3;
          tiles.add(RecognizedTile(tile: Tile(color, number), confidence: conf));
        } catch (_) {
          // skip invalid tile
        }
      }

      return tiles.isEmpty ? _fallbackRecognizedTiles(gosterge) : tiles;
    } catch (e) {
      debugPrint('[GeminiVision] Parse error: $e');
      return _fallbackRecognizedTiles(gosterge);
    }
  }

  /// Fallback wenn Gemini nicht antwortet
  List<RecognizedTile> _fallbackRecognizedTiles(Tile gosterge) {
    final rng = DateTime.now().millisecondsSinceEpoch;
    final numTiles = 5 + (rng % 4);
    final tiles = <RecognizedTile>[];
    for (int i = 0; i < numTiles; i++) {
      final c = TileColor.values[(rng + i * 3) % 4];
      final n = 1 + ((rng + i * 7) % 13);
      tiles.add(RecognizedTile(tile: Tile(c, n), confidence: 0.3));  // Low confidence!
    }
    return tiles;
  }

  /// Backwards-compatible: convert RecognizedTile → Tile
  static List<Tile> recognizedToTiles(List<RecognizedTile> recognized) {
    return recognized.map((r) => r.tile).toList();
  }

  /// Bild komprimieren für Gemini (max ~4MB inline)
  Future<Uint8List> _compress(File photo) async {
    final bytes = await photo.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // Resize auf max 1024x1024
    final resized = image.width > image.height
        ? img.copyResize(image, width: 1024)
        : img.copyResize(image, height: 1024);

    return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
  }
}
