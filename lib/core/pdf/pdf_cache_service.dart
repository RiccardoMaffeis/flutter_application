import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart' as fbs;

/// Base sealed type representing a resolved PDF source (either local file or network URL).
sealed class PdfSource {
  const PdfSource();
}

/// Resolved PDF that lives as a local file on the device.
class PdfFile extends PdfSource {
  final String path;
  const PdfFile(this.path);
}

/// Resolved PDF that should be opened via a network URL (Web).
class PdfNetwork extends PdfSource {
  final String url;
  const PdfNetwork(this.url);
}

/// A small PDF cache + resolver that retrieves files from Firebase Storage,
/// persists them locally on mobile/desktop, and memoizes signed URLs on Web.
///
/// Usage:
///   final src = await PdfCacheService.instance.resolveByFamilyAndId(
///     famUpper: 'XT1',
///     productId: '1SDA123456R1',
///   );
///   if (src is PdfFile)   -> open from src.path
///   if (src is PdfNetwork)-> open from src.url
class PdfCacheService {
  /// Private constructor; prefer the singleton [instance].
  PdfCacheService._({this.rootFolder = '', this.bucket});

  /// Global singleton instance.
  static final PdfCacheService instance = PdfCacheService._(
    rootFolder: '',
    bucket: null,
  );

  /// Optional prefix path inside the storage bucket, e.g. "datasheets".
  final String rootFolder;

  /// Optional custom bucket name; if null, uses the default Firebase Storage instance.
  final String? bucket;

  /// In-memory cache for Web download URLs keyed by storage relative path.
  final _urlCache = <String, String>{};

  /// Deduplication map to avoid concurrent duplicate fetches for the same key.
  /// Key shape: "FAMILY|PRODUCTID".
  final _inflight = <String, Future<PdfSource?>>{};

  /// Returns the Firebase Storage instance, optionally bound to a specific bucket.
  fbs.FirebaseStorage get _storage => bucket == null
      ? fbs.FirebaseStorage.instance
      : fbs.FirebaseStorage.instanceFor(bucket: bucket!);

  /// Ensures a persistent application support subfolder for storing cached PDFs.
  Future<Directory> _cacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/pdf_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Builds one or more candidate relative paths for a given family and product id.
  /// You can extend this to return multiple fallbacks if your storage layout varies.
  List<String> _pathsFor(String famUpper, String productId) {
    final p = rootFolder.isNotEmpty
        ? '$rootFolder/$famUpper/$productId.pdf'
        : '$famUpper/$productId.pdf';
    return [p];
  }

  /// Converts a storage-relative path to a local filesystem path under the cache dir.
  String _localPath(String cacheDir, String relPath) {
    final clean = relPath.replaceAll(RegExp(r'^\/*'), '');
    return '$cacheDir/$clean';
  }

  /// Public entry point that resolves a PDF for a given (family, productId).
  /// It deduplicates concurrent requests for the same pair.
  Future<PdfSource?> resolveByFamilyAndId({
    required String famUpper,
    required String productId,
  }) async {
    final key = '$famUpper|$productId';
    if (_inflight.containsKey(key)) return _inflight[key];

    final fut = _resolveImpl(famUpper: famUpper, productId: productId);
    _inflight[key] = fut;
    try {
      return await fut;
    } finally {
      _inflight.remove(key);
    }
  }

  /// Internal resolution strategy:
  /// - On mobile/desktop: check local cache, else download file to cache and return [PdfFile].
  /// - On Web: fetch a signed URL and memoize it in-memory, returning [PdfNetwork].
  Future<PdfSource?> _resolveImpl({
    required String famUpper,
    required String productId,
  }) async {
    final storage = _storage;
    final paths = _pathsFor(famUpper, productId);

    if (!kIsWeb) {
      // Native platforms: prefer local cache if present.
      final cache = await _cacheDir();

      // 1) Hit local cache first.
      for (final rel in paths) {
        final path = _localPath(cache.path, rel);
        final f = File(path);
        if (await f.exists()) return PdfFile(f.path);
      }

      // 2) Otherwise, attempt download from Firebase Storage.
      for (final rel in paths) {
        try {
          final ref = storage.ref(rel);
          final outPath = _localPath(cache.path, rel);
          final outFile = File(outPath);

          await outFile.parent.create(recursive: true);

          // Streams the remote object to a local file.
          await ref.writeToFile(outFile);
          return PdfFile(outFile.path);
        } on fbs.FirebaseException catch (e) {
          // Ignore "object-not-found" for this candidate and try next path.
          if (e.code == 'object-not-found') continue;
          // Propagate other storage errors to the caller.
          rethrow;
        }
      }
      // Nothing found for any candidate path.
      return null;
    } else {
      // Web: build/return memoized signed URL (no filesystem).
      for (final rel in paths) {
        final cached = _urlCache[rel];
        if (cached != null) return PdfNetwork(cached);
        try {
          final url = await storage.ref(rel).getDownloadURL();
          _urlCache[rel] = url;
          return PdfNetwork(url);
        } on fbs.FirebaseException catch (e) {
          // Try next candidate if the object doesn't exist here.
          if (e.code == 'object-not-found') continue;
          rethrow;
        }
      }
      return null;
    }
  }

  /// Forces a refresh for a given (family, productId):
  /// - On native: deletes local cached files for all candidate paths.
  /// - On Web: clears the in-memory URL cache for those paths.
  /// Then re-runs the normal resolution flow.
  Future<PdfSource?> forceRefresh({
    required String famUpper,
    required String productId,
  }) async {
    if (!kIsWeb) {
      final cache = await _cacheDir();
      for (final rel in _pathsFor(famUpper, productId)) {
        final path = _localPath(cache.path, rel);
        final f = File(path);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    } else {
      for (final rel in _pathsFor(famUpper, productId)) {
        _urlCache.remove(rel);
      }
    }
    return resolveByFamilyAndId(famUpper: famUpper, productId: productId);
  }
}
