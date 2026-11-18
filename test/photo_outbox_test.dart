import 'dart:async';
import 'dart:io';

import 'package:ag_merchandising/services/photo_outbox.dart';
import 'package:ag_merchandising/services/photo_capture_time.dart';
import 'package:ag_merchandising/core/logging/app_logger_v2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _LostPicker extends ImagePicker {
  _LostPicker(this.file);
  final File? file;
  int calls = 0;

  @override
  Future<LostDataResponse> retrieveLostData() async {
    calls++;
    return LostDataResponse(files: file == null ? null : [XFile(file!.path)]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  appLogger.initialize();
  sqfliteFfiInit();
  late Directory folder;
  late Database db;
  int? user = 7;

  setUp(() async {
    user = 7;
    folder = await Directory.systemTemp.createTemp('photo-outbox-');
    db = await databaseFactoryFfi.openDatabase(p.join(folder.path, 'test.db'),
        options: OpenDatabaseOptions(
            version: 1, onCreate: (db, _) => PhotoOutbox.createSchema(db)));
  });

  tearDown(() async {
    PhotoCaptureTime.clientFactory = http.Client.new;
    await db.close();
    await folder.delete(recursive: true);
  });

  PhotoOutbox store([PhotoUpload? upload]) => PhotoOutbox.testing(db, folder,
      currentUser: () async => user,
      upload: upload ?? (file, id, owner) async => '/uploads/$id.jpg');

  Future<String> begin(PhotoOutbox outbox, {String type = 'photo'}) =>
      outbox.begin(
          brandId: 30,
          brandName: 'BANANA BRASIL',
          storeId: 208,
          fieldName: 'fotos',
          fieldType: type,
          fieldLabel: 'Fotos',
          multiple: type == 'photo');

  test('camera result survives store restart with correct route and field',
      () async {
    var outbox = store();
    await outbox.openAttendance(30, 'BANANA BRASIL', 208);
    final id = await begin(outbox);
    final source = File(p.join(folder.path, 'camera-cache.jpg'));
    await source.writeAsBytes([1, 2, 3, 4], flush: true);

    await db.close();
    db = await databaseFactoryFfi.openDatabase(p.join(folder.path, 'test.db'));
    outbox = store();
    await outbox.recoverLostData(_LostPicker(source));
    final jobs = await outbox.jobs(30, 208);
    expect(jobs.single['id'], id);
    expect(jobs.single['field_name'], 'fotos');
    expect(jobs.single['status'], 'review');
    final durable = File(jobs.single['local_path'] as String);
    await source.delete();
    expect(await durable.readAsBytes(), [1, 2, 3, 4]);
    expect((await outbox.activeAttendance())?['store_id'], 208);
    await outbox.ready(id, durable);
    await outbox.sync();
    expect(
        PhotoOutbox.merge({
          'fotos': ['/uploads/existing.jpg']
        }, await outbox.jobs(30, 208))['fotos'],
        ['/uploads/existing.jpg', '/uploads/$id.jpg']);
  });

  test('failed upload stays durable and concurrent retries use one worker',
      () async {
    var attempts = 0;
    var active = 0;
    var maxActive = 0;
    final ids = <String>[];
    var outbox = store((file, id, owner) async {
      ids.add(id);
      attempts++;
      if (attempts == 1) throw const SocketException('offline');
      active++;
      if (active > maxActive) maxActive = active;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      active--;
      return '/uploads/$id.jpg';
    });
    final id = await begin(outbox);
    final source = File(p.join(folder.path, 'camera.jpg'));
    await source.writeAsBytes([1, 2], flush: true);
    final durable = await outbox.persist(id, source);
    await outbox.ready(id, durable);
    await expectLater(outbox.sync(), throwsA(isA<SocketException>()));
    expect((await outbox.jobs(30, 208)).single['status'], 'queued');
    expect(await durable.exists(), isTrue);
    final uploader = (File file, String id, int owner) async {
      ids.add(id);
      active++;
      if (active > maxActive) maxActive = active;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      active--;
      return '/uploads/$id.jpg';
    };
    outbox = store(uploader);
    await Future.wait([outbox.sync(), outbox.sync(), outbox.sync()]);
    expect(ids, [id, id]);
    expect(maxActive, 1);
    expect((await outbox.jobs(30, 208)).single['status'], 'uploaded');
  });

  test('timed out photo survives restart and reuses its capture receipt ID',
      () async {
    final attempts = <String>[];
    var outbox = store((file, id, owner) async {
      attempts.add(id);
      throw TimeoutException('upload', const Duration(seconds: 90));
    });
    final id = await begin(outbox);
    final source = File(p.join(folder.path, 'iphone-camera.jpg'));
    await source.writeAsBytes([1, 2, 3], flush: true);
    final durable = await outbox.persist(id, source);
    await outbox.ready(id, durable);
    await source.delete();
    await expectLater(outbox.sync(), throwsA(isA<TimeoutException>()));
    outbox = store((file, id, owner) async {
      attempts.add(id);
      expect(await file.readAsBytes(), [1, 2, 3]);
      return '/uploads/recovered.jpg';
    });
    await outbox.sync();
    expect(attempts, [id, id]);
    expect((await outbox.jobs(30, 208)).single['photo_url'],
        '/uploads/recovered.jpg');
    expect(await durable.exists(), isTrue);
  });

  test('persisted native capture recovers without Android lost data API',
      () async {
    var outbox = store();
    final id = await begin(outbox);
    final source = File(p.join(folder.path, 'native-camera.jpg'));
    await source.writeAsBytes([7, 8, 9], flush: true);
    final durable = await outbox.persist(id, source);
    await source.delete();
    outbox = store();
    await outbox.recoverLostData();
    final job = (await outbox.jobs(30, 208)).single;
    expect(job['id'], id);
    expect(job['status'], 'review');
    expect(await durable.readAsBytes(), [7, 8, 9]);
  });

  test('another account cannot consume, display or upload a pending capture',
      () async {
    final outbox = store();
    await outbox.openAttendance(30, 'BANANA BRASIL', 208);
    await begin(outbox);
    user = 8;
    final picker = _LostPicker(null);
    await expectLater(outbox.recoverLostData(picker), throwsStateError);
    expect(picker.calls, 0);
    expect(await outbox.activeAttendance(), isNull);
    expect(await outbox.jobs(30, 208), isEmpty);
    await outbox.sync();
    user = 7;
    expect((await outbox.jobs(30, 208)).length, 1);
  });

  test(
      'file committed before journal update is recovered and text is preserved',
      () async {
    final outbox = store();
    final id = await begin(outbox, type: 'photo_text');
    final durable = File(p.join(folder.path, '$id.jpg'));
    await durable.writeAsBytes([8, 9], flush: true);
    await outbox.recoverLostData(_LostPicker(null));
    expect((await outbox.jobs(30, 208)).single['local_path'], durable.path);
    await outbox.ready(id, durable);
    var merged = PhotoOutbox.merge({
      'fotos': {'photo': durable.path, 'text': 'etiqueta'}
    }, await outbox.jobs(30, 208));
    await outbox.sync();
    merged = PhotoOutbox.merge(merged, await outbox.jobs(30, 208));
    expect(merged['fotos'], {'photo': '/uploads/$id.jpg', 'text': 'etiqueta'});
    await outbox.removePhoto('/uploads/$id.jpg');
    expect(await outbox.jobs(30, 208), isEmpty);
    await outbox.complete(30, 208);
    expect(await durable.exists(), isFalse);
  });

  test('new capture stays in review until its server proof exists', () async {
    final outbox = store();
    final id = await begin(outbox);
    await outbox.setTimeToken(id, 'reference');
    final source = File(p.join(folder.path, 'photo.jpg'));
    await source.writeAsBytes([1, 2]);
    final saved = await outbox.persist(id, source);
    await expectLater(outbox.ready(id, saved), throwsStateError);
    expect((await outbox.jobs(30, 208)).single['status'], 'review');
    await PhotoCaptureTime.proofFile(saved).writeAsString('proof');
    await outbox.ready(id, saved);
    expect((await outbox.jobs(30, 208)).single['status'], 'queued');
  });

  test('a photo remains recoverable if connection drops after capture',
      () async {
    final outbox = store();
    final id = await begin(outbox);
    await outbox.setTimeToken(id, 'reference');
    final source = File(p.join(folder.path, 'photo.jpg'));
    await source.writeAsBytes([1, 2]);
    final saved = await outbox.persist(id, source);
    PhotoCaptureTime.clientFactory = () => MockClient((_) async {
          throw const SocketException('offline');
        });
    await expectLater(outbox.ensureTimeProof(id, saved), throwsStateError);
    expect(await saved.exists(), isTrue);
    expect((await outbox.jobs(30, 208)).single['status'], 'review');
    PhotoCaptureTime.clientFactory = () => MockClient(
        (_) async => http.Response('{"success":true,"proof":"proof"}', 200));
    await outbox.ensureTimeProof(id, saved);
    await outbox.ready(id, saved);
    await outbox.sync();
    expect((await outbox.jobs(30, 208)).single['status'], 'uploaded');
    await outbox.complete(30, 208);
    expect(await saved.exists(), isFalse);
    expect(await PhotoCaptureTime.proofFile(saved).exists(), isFalse);
  });

  test('upgrading the queue preserves existing photo jobs', () async {
    final oldPath = p.join(folder.path, 'old.db');
    var oldDb = await databaseFactoryFfi.openDatabase(oldPath,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              await db.execute(
                  'CREATE TABLE photo_jobs (id TEXT PRIMARY KEY, status TEXT)');
              await db
                  .insert('photo_jobs', {'id': 'existing', 'status': 'queued'});
            }));
    await oldDb.close();
    oldDb = await databaseFactoryFfi.openDatabase(oldPath,
        options: OpenDatabaseOptions(
            version: 2, onUpgrade: PhotoOutbox.upgradeSchema));
    final rows = await oldDb.query('photo_jobs');
    expect(rows.single['id'], 'existing');
    expect(rows.single['status'], 'queued');
    expect(rows.single['time_token'], isNull);
    await oldDb.close();
  });

  test(
      'offline completion retains files without merging them into the next visit',
      () async {
    final outbox = store();
    final id = await begin(outbox);
    final source = File(p.join(folder.path, 'offline.jpg'));
    await source.writeAsBytes([3, 4]);
    final durable = await outbox.persist(id, source);
    await outbox.ready(id, durable);
    await outbox.submitJobs([id], 30, 208);
    expect(await outbox.jobs(30, 208), isEmpty);
    expect(await durable.exists(), isTrue);
    await outbox.complete(30, 208);
    expect(await durable.exists(), isTrue);
    await outbox.completeSubmitted([id]);
    expect(await durable.exists(), isFalse);
  });
}
