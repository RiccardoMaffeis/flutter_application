import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart' as fbs;

sealed class PdfSource { const PdfSource(); }
class PdfFile extends PdfSource { final String path; const PdfFile(this.path); }
class PdfNetwork extends PdfSource { final String url; const PdfNetwork(this.url); }

class PdfCacheService {
  PdfCacheService._({this.rootFolder = '', this.bucket});
  static final PdfCacheService instance =
      PdfCacheService._(rootFolder: '', bucket: null);

  final String rootFolder;
  final String? bucket;
  final _urlCache = <String, String>{};
  final _inflight = <String, Future<PdfSource?>>{};

  fbs.FirebaseStorage get _storage =>
      bucket == null ? fbs.FirebaseStorage.instance
                     : fbs.FirebaseStorage.instanceFor(bucket: bucket!);

  Future<Directory> _cacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/pdf_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  List<String> _pathsFor(String famUpper, String productId) {
    final p = rootFolder.isNotEmpty
        ? '$rootFolder/$famUpper/$productId.pdf'
        : '$famUpper/$productId.pdf';
    return [p];
  }

  String _localPath(String cacheDir, String relPath) {
    final clean = relPath.replaceAll(RegExp(r'^\/*'), '');
    return '$cacheDir/$clean';
  }

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

  Future<PdfSource?> _resolveImpl({
    required String famUpper,
    required String productId,
  }) async {
    final storage = _storage;
    final paths = _pathsFor(famUpper, productId);

    if (!kIsWeb) {
      final cache = await _cacheDir();

      for (final rel in paths) {
        final path = _localPath(cache.path, rel);
        final f = File(path);
        if (await f.exists()) return PdfFile(f.path);
      }

      for (final rel in paths) {
        try {
          final ref = storage.ref(rel);
          final outPath = _localPath(cache.path, rel);
          final outFile = File(outPath);

          await outFile.parent.create(recursive: true);

          await ref.writeToFile(outFile);
          return PdfFile(outFile.path);
        } on fbs.FirebaseException catch (e) {
          if (e.code == 'object-not-found') continue;
          rethrow;
        }
      }
      return null;
    } else {
      for (final rel in paths) {
        final cached = _urlCache[rel];
        if (cached != null) return PdfNetwork(cached);
        try {
          final url = await storage.ref(rel).getDownloadURL();
          _urlCache[rel] = url;
          return PdfNetwork(url);
        } on fbs.FirebaseException catch (e) {
          if (e.code == 'object-not-found') continue;
          rethrow;
        }
      }
      return null;
    }
  }

  Future<PdfSource?> forceRefresh({
    required String famUpper,
    required String productId,
  }) async {
    if (!kIsWeb) {
      final cache = await _cacheDir();
      for (final rel in _pathsFor(famUpper, productId)) {
        final path = _localPath(cache.path, rel);
        final f = File(path);
        if (await f.exists()) { try { await f.delete(); } catch (_) {} }
      }
    } else {
      for (final rel in _pathsFor(famUpper, productId)) {
        _urlCache.remove(rel);
      }
    }
    return resolveByFamilyAndId(famUpper: famUpper, productId: productId);
  }
}
