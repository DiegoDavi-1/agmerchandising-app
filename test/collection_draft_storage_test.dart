import 'package:ag_merchandising/services/collection_draft_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('rascunho volta no mesmo dia e por usuario/marca/loja', () async {
    final day = DateTime(2026, 10, 17, 9);
    final key = CollectionDraftStorage.key(7, 3, 110);
    await CollectionDraftStorage.save(
        key,
        {
          'fotos': ['/uploads/a.jpg', '/uploads/b.jpg'],
          'obs': 'ok'
        },
        now: day);

    final restored = await CollectionDraftStorage.load(key,
        now: day.add(const Duration(hours: 8)));
    expect(restored?['fotos'], ['/uploads/a.jpg', '/uploads/b.jpg']);
    expect(
        await CollectionDraftStorage.load(CollectionDraftStorage.key(8, 3, 110),
            now: day),
        isNull);
  });

  test('rascunho permanece ao mudar o dia do celular ou trabalhar offline',
      () async {
    final key = CollectionDraftStorage.key(7, 3, 110);
    await CollectionDraftStorage.save(key, {'obs': 'ontem'},
        now: DateTime(2026, 10, 16, 18));
    expect(
        await CollectionDraftStorage.load(key, now: DateTime(2026, 10, 17, 8)),
        {'obs': 'ontem'});
  });

  test('clear apaga o rascunho', () async {
    final key = CollectionDraftStorage.key(7, 3, null);
    await CollectionDraftStorage.save(key, {'obs': 'x'});
    await CollectionDraftStorage.clear(key);
    expect(await CollectionDraftStorage.load(key), isNull);
  });

  test(
      'saved attendance survives restart with its request and checkout pending',
      () async {
    final key = CollectionDraftStorage.key(7, 31, 154);
    final request = {
      'data': {
        'fotos': ['/uploads/a.jpg']
      },
      'event_time': {'source': 'unverified', 'device_ms': 123},
      'photo_job_ids': ['capture-a'],
    };
    await CollectionDraftStorage.save(
        key,
        {
          'fotos': ['/uploads/a.jpg']
        },
        submissionId: 'a' * 32,
        submissionRequest: request,
        submissionResult: {
          'success': true,
          'collection_id': 99,
          'requires_clock_out': true
        });
    final restored = await CollectionDraftStorage.loadSession(key);
    expect(restored?.submissionId, 'a' * 32);
    expect(restored?.submissionRequest, request);
    expect(restored?.submissionResult?['collection_id'], 99);
    expect(restored?.submissionResult?['requires_clock_out'], true);
    expect(
        await CollectionDraftStorage.load(
            CollectionDraftStorage.key(8, 31, 154)),
        isNull);
  });

  test('completion cannot be overwritten by an older draft write', () async {
    final key = CollectionDraftStorage.key(7, 31, 154);
    final pending = CollectionDraftStorage.save(key, {
      'fotos': ['a']
    });
    final saved = CollectionDraftStorage.save(
        key,
        {
          'fotos': ['a', 'b']
        },
        submissionId: 'b' * 32,
        submissionResult: {'success': true, 'collection_id': 99});
    await Future.wait([pending, saved]);
    expect(
        (await CollectionDraftStorage.loadSession(key))
            ?.submissionResult?['collection_id'],
        99);
    await Future.wait([
      CollectionDraftStorage.save(key, {
        'fotos': ['a']
      }),
      CollectionDraftStorage.clear(key),
    ]);
    expect(await CollectionDraftStorage.load(key), isNull);
  });

  test('corrupt draft is reported and retained instead of deleted', () async {
    final key = CollectionDraftStorage.key(7, 31, 154);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, '{invalid');
    await expectLater(
        CollectionDraftStorage.loadSession(key), throwsFormatException);
    expect(prefs.getString(key), '{invalid');
  });
}
