// lib/services/photo_storage_service.dart
// RenkliOkeyScout — Foto-Upload zu Supabase Storage
//
// Anti-Cheat: Speichert Foto als BEWEIS für Strafsteine.
// Perplexity Best Practice: "Store original image, OCR output, user-edited score as distinct records"

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoStorageService {
  static const _bucket = 'round-photos';
  final _supabase = Supabase.instance.client;

  /// Upload ein Foto zu Supabase Storage.
  /// Returns: Public URL des Fotos, oder null bei Fehler.
  Future<String?> uploadPhoto({
    required File photo,
    required String tableId,
    required int roundNumber,
    required String playerId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('[PhotoStorage] No auth user');
        return null;
      }

      // Pfad: round-photos/{tableId}/round{roundNumber}/{playerId}.jpg
      final ext = p.extension(photo.path).isEmpty ? '.jpg' : p.extension(photo.path);
      final path = '$tableId/round$roundNumber/$playerId$ext';

      final bytes = await photo.readAsBytes();
      await _supabase.storage.from(_bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final url = _supabase.storage.from(_bucket).getPublicUrl(path);
      debugPrint('[PhotoStorage] Uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('[PhotoStorage] Upload failed: $e');
      return null;
    }
  }

  /// Prüfe ob Bucket existiert und öffentlich ist
  Future<bool> checkBucket() async {
    try {
      final buckets = await _supabase.storage.listBuckets();
      return buckets.any((b) => b.name == _bucket);
    } catch (e) {
      debugPrint('[PhotoStorage] Bucket check failed: $e');
      return false;
    }
  }
}
