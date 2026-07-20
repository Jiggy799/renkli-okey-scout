// lib/services/collect_service.dart
// RenkliOkeyScout — Training data collector
//
// Stores labelled tile photos in Supabase Storage + metadata in DB.
// This is the data that will be used to train the on-device TFLite model.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// One labelled tile inside a training photo.
/// Bounding box is normalised 0..1 (relative to image size).
class TileLabel {
  final String color; // 'yellow' | 'blue' | 'red' | 'black' | 'sahte'
  final int number; // 1..13
  final bool isFalseOkey; // sahte okey marker
  final double x; // 0..1
  final double y; // 0..1
  final double w; // 0..1
  final double h; // 0..1

  const TileLabel({
    required this.color,
    required this.number,
    required this.isFalseOkey,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  Map<String, dynamic> toJson() => {
        'color': color,
        'number': number,
        'is_false_okey': isFalseOkey,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
      };
}

class CollectService {
  final _supabase = Supabase.instance.client;

  /// Upload one labelled training photo.
  /// Returns true on success.
  Future<bool> uploadSample({
    required File imageFile,
    required List<TileLabel> tiles,
    String? gostergeColor,
    int? gostergeNumber,
    String? notes,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        // Sign in anonymously so we can track who's contributing
        await _supabase.auth.signInAnonymously();
      }
      final uploader = _supabase.auth.currentUser;

      final bytes = await imageFile.readAsBytes();
      final hash = DateTime.now().millisecondsSinceEpoch.toString();
      final path = 'samples/${uploader!.id}/$hash.jpg';

      // 1. Upload image to storage
      await _supabase.storage.from('training-data').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      // 2. Get public URL
      final publicUrl =
          _supabase.storage.from('training-data').getPublicUrl(path);

      // 3. Insert metadata row
      await _supabase.from('training_samples').insert({
        'uploader_id': uploader.id,
        'image_path': path,
        'image_url': publicUrl,
        'gosterge_color': gostergeColor,
        'gosterge_number': gostergeNumber,
        'tiles': tiles.map((t) => t.toJson()).toList(),
        'notes': notes,
        'tile_count': tiles.length,
      });

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Upload failed: $e');
      return false;
    }
  }

  /// Get total count of samples (for the progress display).
  Future<int> totalSamples() async {
    try {
      final r = await _supabase
          .from('training_samples')
          .select('id')
          .count(CountOption.exact);
      return (r as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Group counts by tile color/number (for progress visualisation).
  Future<Map<String, int>> sampleStats() async {
    try {
      final r = await _supabase.from('training_samples').select('tiles');
      final counts = <String, int>{};
      for (final row in r as List) {
        final tiles = row['tiles'] as List<dynamic>? ?? [];
        for (final t in tiles) {
          final m = t as Map<String, dynamic>;
          final key = '${m['color']}_${m['number']}';
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
      return counts;
    } catch (_) {
      return {};
    }
  }
}
