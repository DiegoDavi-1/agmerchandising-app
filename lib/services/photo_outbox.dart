import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/logging/app_logger_v2.dart';
import 'api_service.dart';
import 'photo_capture_time.dart';

typedef PhotoUpload = Future<String> Function(File file, String id, int userId);

class PhotoOutbox extends ChangeNotifier {
  PhotoOutbox._()
      : _currentUserOverride = null,
        _uploadOverride = null;

  @visibleForTesting
  PhotoOutbox.testing(Database database, Directory directory,
      {required Future<int?> Function() currentUser,
      required PhotoUpload upload})
      : _database = Future.value(database),
        _directory = Future.value(directory),
        _currentUserOverride = currentUser,
        _uploadOverride = upload;

  static final instance = PhotoOutbox._();
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;
  Future<Database>? _database;
  Future<Directory>? _directory;
  final Future<int?> Function()? _currentUserOverride;
  final PhotoUpload? _uploadOverride;
  Future<void>? _syncing;
  Timer? _retryTimer;
  String? lastError;

  static Future<void> createSchema(Database db) async {
    await db.execute('''CREATE TABLE photo_jobs (
      id TEXT PRIMARY KEY, user_id INTEGER NOT NULL, brand_id INTEGER NOT NULL,
      brand_name TEXT NOT NULL, store_id INTEGER NOT NULL, field_name TEXT NOT NULL,
      field_type TEXT NOT NULL, field_label TEXT NOT NULL, multiple INTEGER NOT NULL,
      local_path TEXT, source_path TEXT, photo_url TEXT, status TEXT NOT NULL,
      error TEXT, created_at INTEGER NOT NULL, time_token TEXT)''');
    await db.execute('''CREATE TABLE photo_attendance (
      user_id INTEGER PRIMARY KEY, brand_id INTEGER NOT NULL,
      brand_name TEXT NOT NULL, store_id INTEGER NOT NULL)''');
  }

  @visibleForTesting
  static Future<void> upgradeSchema(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE photo_jobs ADD COLUMN time_token TEXT');
    }
  }

  Future<Database> get database => _database ??= () async {
        final directory = await getDatabasesPath();
        return openDatabase(p.join(directory, 'photo_outbox_v1.db'),
            version: 2,
            onCreate: (db, _) => createSchema(db),
            onUpgrade: upgradeSchema);
      }();

  Future<Directory> get directory => _directory ??= () async {
        final support = await getApplicationSupportDirectory();
        return Directory(p.join(support.path, 'attendance_photos'))
            .create(recursive: true);
      }();

  Future<int?> currentUserId() async {
    final override = _currentUserOverride;
    if (override != null) return override();
    if (!ApiService.isAuthenticated()) return null;
    final user = await ApiService.getUserData();
    return int.tryParse('${user?['id']}');
  }

  Future<int> _requireUser() async {
    final id = await currentUserId();
    if (id == null)
      throw StateError('Entre novamente para recuperar as fotos.');
    return id;
  }

  Future<void> openAttendance(
      int brandId, String brandName, int? storeId) async {
    final db = await database;
    await db.insert(
        'photo_attendance',
        {
          'user_id': await _requireUser(),
          'brand_id': brandId,
          'brand_name': brandName,
          'store_id': storeId ?? 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>?> activeAttendance() async {
    final userId = await currentUserId();
    if (userId == null) return null;
    final rows = await (await database).query('photo_attendance',
        where: 'user_id = ?', whereArgs: [userId], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> closeAttendance(int brandId, int? storeId) async {
    final id = await currentUserId();
    if (id == null) return;
    final db = await database;
    await db.delete('photo_attendance',
        where: 'user_id = ? AND brand_id = ? AND store_id = ?',
        whereArgs: [id, brandId, storeId ?? 0]);
    await db.update('photo_jobs', {'status': 'removed'},
        where: '''user_id = ? AND brand_id = ? AND store_id = ?
          AND status = 'capturing' AND local_path IS NULL''',
        whereArgs: [id, brandId, storeId ?? 0]);
  }

  Future<String> begin({
    required int brandId,
    required String brandName,
    required int? storeId,
    required String fieldName,
    required String fieldType,
    required String fieldLabel,
    required bool multiple,
  }) async {
    final random = Random.secure();
    final id = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    await (await database).insert('photo_jobs', {
      'id': id,
      'user_id': await _requireUser(),
      'brand_id': brandId,
      'brand_name': brandName,
      'store_id': storeId ?? 0,
      'field_name': fieldName,
      'field_type': fieldType,
      'field_label': fieldLabel,
      'multiple': multiple ? 1 : 0,
      'status': 'capturing',
      'created_at': DateTime.now().microsecondsSinceEpoch,
    });
    return id;
  }

  Future<Map<String, Object?>> _job(String id) async {
    final rows = await (await database).query('photo_jobs',
        where: 'id = ? AND user_id = ?', whereArgs: [id, await _requireUser()]);
    if (rows.isEmpty) throw StateError('Captura nao pertence a esta conta.');
    return rows.single;
  }

  Future<void> setTimeToken(String id, String token) async {
    final job = await _job(id);
    final previous = job['local_path'];
    if (previous is String) {
      final file = File(previous);
      final proof = PhotoCaptureTime.proofFile(file);
      if (await proof.exists()) await proof.delete();
      if (await file.exists()) await file.delete();
    }
    await (await database).update(
        'photo_jobs',
        {
          'time_token': token,
          'local_path': null,
          'source_path': null,
          'status': 'capturing',
          'error': null,
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> ensureTimeProof(String id, File file) async {
    final job = await _job(id);
    final token = job['time_token'];
    if (token is String && !await PhotoCaptureTime.proofFile(file).exists()) {
      await PhotoCaptureTime.seal(file, token, recovered: true);
    }
  }

  Future<File> persist(String id, File source) async {
    await _job(id);
    await (await database).update('photo_jobs', {'source_path': source.path},
        where: 'id = ?', whereArgs: [id]);
    final folder = await directory;
    final destination = File(p.join(folder.path, '$id.jpg'));
    if (source.path != destination.path) {
      final part = File('${destination.path}.part');
      await source.openRead().pipe(part.openWrite());
      final handle = await part.open(mode: FileMode.append);
      await handle.flush();
      await handle.close();
      await part.rename(destination.path);
    }
    await (await database).update('photo_jobs',
        {'local_path': destination.path, 'status': 'review', 'error': null},
        where: 'id = ?', whereArgs: [id]);
    return destination;
  }

  Future<void> ready(String id, File accepted) async {
    final job = await _job(id);
    if (job['time_token'] is String &&
        !await PhotoCaptureTime.proofFile(accepted).exists()) {
      throw StateError(
          'Os metadados de captura da foto ainda nao foram salvos.');
    }
    await (await database).update('photo_jobs',
        {'local_path': accepted.path, 'status': 'queued', 'error': null},
        where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<void> cancel(String id) async {
    await _job(id);
    await (await database).update('photo_jobs', {'status': 'removed'},
        where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<void> cancelIfUncaptured(String id) async {
    await _job(id);
    await (await database).update('photo_jobs', {'status': 'removed'},
        where:
            "id = ? AND status = 'capturing' AND local_path IS NULL AND source_path IS NULL",
        whereArgs: [id]);
    notifyListeners();
  }

  Future<void> removePhoto(String path) async {
    await (await database).update('photo_jobs', {'status': 'removed'},
        where: 'user_id = ? AND (local_path = ? OR photo_url = ?)',
        whereArgs: [await _requireUser(), path, path]);
    notifyListeners();
  }

  Future<List<Map<String, Object?>>> jobs(int brandId, int? storeId) async {
    return (await database).query('photo_jobs',
        where:
            "user_id = ? AND brand_id = ? AND store_id = ? AND status NOT IN ('removed', 'submitted')",
        whereArgs: [await _requireUser(), brandId, storeId ?? 0],
        orderBy: 'created_at, id');
  }

  static Map<String, dynamic> merge(
      Map<String, dynamic> data, List<Map<String, Object?>> jobs) {
    final merged = Map<String, dynamic>.from(data);
    for (final job in jobs) {
      if (job['status'] != 'queued' && job['status'] != 'uploaded') continue;
      final local = job['local_path'] as String?;
      final value = job['photo_url'] as String? ?? local;
      if (value == null) continue;
      final name = job['field_name'] as String;
      if (job['field_type'] == 'photo_text') {
        final current = merged[name];
        merged[name] = {
          if (current is Map) ...Map<String, dynamic>.from(current),
          'photo': value,
        };
      } else if (job['multiple'] == 1) {
        final current = merged[name];
        final values =
            current is List ? List<String>.from(current) : <String>[];
        final index = values.indexOf(local ?? value);
        if (index >= 0) values[index] = value;
        if (!values.contains(value)) values.add(value);
        merged[name] = values.toSet().toList();
      } else {
        merged[name] = value;
      }
    }
    return merged;
  }

  Future<void> recoverLostData([ImagePicker? picker]) async {
    final userId = await currentUserId();
    if (userId == null) return;
    final db = await database;
    final pending = await db.query('photo_jobs',
        where: "status IN ('capturing', 'review')",
        orderBy: 'created_at DESC',
        limit: 1);
    // The picker cache is global; never consume another account's capture.
    if (pending.isEmpty) return;
    final job = pending.single;
    if (job['user_id'] != userId) {
      throw StateError('Uma captura pendente pertence a outra conta.');
    }
    final response = picker != null || Platform.isAndroid
        ? await (picker ?? ImagePicker()).retrieveLostData()
        : null;
    if (response?.exception != null) throw response!.exception!;
    final id = job['id'] as String;
    final lost = response?.files;
    if (lost != null && lost.isNotEmpty) {
      await persist(id, File(lost.first.path));
    } else if (job['local_path'] == null) {
      final destination = File(p.join((await directory).path, '$id.jpg'));
      if (await destination.exists()) {
        await persist(id, destination);
      } else if (job['source_path'] is String &&
          await File(job['source_path'] as String).exists()) {
        await persist(id, File(job['source_path'] as String));
      } else {
        await cancel(id);
        lastError = 'A captura foi interrompida antes de gerar o arquivo. '
            'Tire essa foto novamente.';
        notifyListeners();
      }
    }
  }

  Future<void> sync() => _syncing ??= _uploadQueued().whenComplete(() {
        _syncing = null;
      });

  Future<void> _uploadQueued() async {
    final userId = await currentUserId();
    if (userId == null) return;
    final db = await database;
    final pending = await db.query('photo_jobs',
        where: "user_id = ? AND status = 'queued'",
        whereArgs: [userId],
        orderBy: 'created_at, id');
    for (final job in pending) {
      if (await currentUserId() != userId) return;
      try {
        final id = job['id'] as String;
        final file = File(job['local_path'] as String);
        if (!await file.exists())
          throw StateError('Arquivo local da foto ausente.');
        final String url;
        final upload = _uploadOverride;
        if (upload != null) {
          url = await upload(file, id, userId);
        } else {
          final response = await ApiService.uploadPhoto(file,
              captureId: id,
              expectedUserId: userId,
              requireTimeProof: job['time_token'] is String);
          if (response?['success'] != true ||
              response?['photo_url'] is! String) {
            throw StateError('O servidor nao confirmou o envio da foto.');
          }
          url = response!['photo_url'] as String;
        }
        await db.update('photo_jobs',
            {'status': 'uploaded', 'photo_url': url, 'error': null},
            where: "id = ? AND user_id = ? AND status = 'queued'",
            whereArgs: [id, userId]);
        lastError = null;
        notifyListeners();
      } catch (error, stack) {
        lastError = 'Foto salva no aparelho. Falha no envio: $error';
        await db.update('photo_jobs', {'error': lastError},
            where: 'id = ?', whereArgs: [job['id']]);
        appLogger.error('Falha na fila de fotos',
            error: error, stackTrace: stack);
        notifyListeners();
        rethrow;
      }
    }
  }

  void retry() {
    unawaited(sync().catchError((Object error, StackTrace stack) {
      lastError ??= 'Nao foi possivel recuperar a fila de fotos: $error';
      appLogger.error('Falha ao retomar fotos',
          error: error, stackTrace: stack);
      notifyListeners();
    }));
  }

  void start() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) => retry());
    retry();
  }

  void pause() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Future<void> complete(int brandId, int? storeId) async {
    final db = await database;
    final records = await db.query('photo_jobs',
        where:
            "user_id = ? AND brand_id = ? AND store_id = ? AND status != 'submitted'",
        whereArgs: [await _requireUser(), brandId, storeId ?? 0]);
    await db.delete('photo_jobs',
        where:
            "user_id = ? AND brand_id = ? AND store_id = ? AND status != 'submitted'",
        whereArgs: [await _requireUser(), brandId, storeId ?? 0]);
    await closeAttendance(brandId, storeId);
    await _deleteFiles(records);
    notifyListeners();
  }

  Future<void> submitJobs(List<String> ids, int brandId, int? storeId) async {
    final db = await database;
    final userId = await _requireUser();
    for (final id in ids) {
      await db.update('photo_jobs', {'status': 'submitted'},
          where: "id = ? AND user_id = ? AND status IN ('queued', 'uploaded')",
          whereArgs: [id, userId]);
    }
    await closeAttendance(brandId, storeId);
    notifyListeners();
  }

  Future<void> completeSubmitted(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final userId = await _requireUser();
    final placeholders = List.filled(ids.length, '?').join(',');
    final where =
        "user_id = ? AND status = 'submitted' AND id IN ($placeholders)";
    final records =
        await db.query('photo_jobs', where: where, whereArgs: [userId, ...ids]);
    await db.delete('photo_jobs', where: where, whereArgs: [userId, ...ids]);
    await _deleteFiles(records);
    notifyListeners();
  }

  Future<void> _deleteFiles(List<Map<String, Object?>> records) async {
    for (final job in records) {
      final paths = {
        if (job['local_path'] is String) job['local_path'] as String,
        p.join((await directory).path, '${job['id']}.jpg'),
      };
      for (final path in paths) {
        final file = File(path);
        try {
          final proof = PhotoCaptureTime.proofFile(file);
          if (await proof.exists()) await proof.delete();
          if (await file.exists()) await file.delete();
        } on FileSystemException catch (error, stack) {
          appLogger.error('Falha ao limpar foto ja enviada',
              error: error, stackTrace: stack);
        }
      }
    }
  }
}
