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

    final restored = await CollectionDraftStorage.load(key, now: day.add(const Duration(hours: 8)));
    expect(restored?['fotos'], ['/uploads/a.jpg', '/uploads/b.jpg']);
    expect(await CollectionDraftStorage.load(CollectionDraftStorage.key(8, 3, 110), now: day), isNull);
  });

  test('rascunho de outro dia e descartado', () async {
    final key = CollectionDraftStorage.key(7, 3, 110);
    await CollectionDraftStorage.save(key, {'obs': 'ontem'}, now: DateTime(2026, 10, 16, 18));
    expect(await CollectionDraftStorage.load(key, now: DateTime(2026, 10, 17, 8)), isNull);
  });

  test('clear apaga o rascunho', () async {
    final key = CollectionDraftStorage.key(7, 3, null);
    await CollectionDraftStorage.save(key, {'obs': 'x'});
    await CollectionDraftStorage.clear(key);
    expect(await CollectionDraftStorage.load(key), isNull);
  });
}
