import 'dart:convert';
import 'dart:io';

import 'package:ag_merchandising/services/offline_clock.dart';
import 'package:ag_merchandising/services/collection_queue_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.merchhub/offline_clock');
  final token = 'header.${base64Url.encode(utf8.encode('{"id":7}'))}.signature';
  var boot = '10';
  var elapsed = 100000;
  var deviceMs = 1800000000000;
  const serverMs = 1800000000000;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    boot = '10';
    elapsed = 100000;
    deviceMs = serverMs;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel,
            (_) async => {
                  'boot_id': boot,
                  'elapsed_ms': elapsed,
                  'device_ms': deviceMs,
                });
    OfflineClock.clientFactory = () => MockClient((request) async {
          expect(jsonDecode(request.body)['boot_id'], '10');
          elapsed += 200;
          return http.Response(
              jsonEncode({
                'token': 'signed-reference',
                'server_ms': serverMs,
              }),
              200);
        });
  });

  tearDown(() {
    OfflineClock.clientFactory = http.Client.new;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('offline attendance retry queues one submission for its owner',
      () async {
    final item = <String, dynamic>{
      '_queue_user_id': 7,
      'client_submission_id': 'a' * 32,
      'data': {
        'fotos': ['/uploads/a.jpg']
      },
    };
    await Future.wait([
      CollectionQueueStorage.enqueue(item),
      CollectionQueueStorage.enqueue(item),
    ]);
    expect(await CollectionQueueStorage.count(), 1);
    await CollectionQueueStorage.enqueue({...item, '_queue_user_id': 8});
    expect(await CollectionQueueStorage.count(), 2);
  });

  test('changing phone date by a day and an hour does not change elapsed time',
      () async {
    await OfflineClock.synchronize('https://example.test/api', token);
    elapsed += 60000;
    deviceMs += const Duration(hours: 25).inMilliseconds;
    final time = await OfflineClock.capture(token);
    expect(time['source'], 'server_reference');
    expect(time['delta_ms'], 60000);
    expect(time['uncertainty_ms'], 200);
    expect(
        time['device_ms'], serverMs + const Duration(hours: 25).inMilliseconds);
  });

  test('saved anchor survives service use while offline but not device restart',
      () async {
    await OfflineClock.synchronize('https://example.test/api', token);
    elapsed += const Duration(hours: 2).inMilliseconds;
    OfflineClock.clientFactory =
        () => MockClient((_) async => throw const SocketException('offline'));
    await OfflineClock.synchronize('https://example.test/api', token);
    expect((await OfflineClock.capture(token))['source'], 'server_reference');
    boot = '11';
    elapsed = 5000;
    final rebooted = await OfflineClock.capture(token);
    expect(rebooted['source'], 'unverified');
    expect(rebooted['reason'], 'device_restarted');
  });

  test('a different account and a stale reference are never verified',
      () async {
    await OfflineClock.synchronize('https://example.test/api', token);
    final another =
        'header.${base64Url.encode(utf8.encode('{"id":8}'))}.signature';
    expect((await OfflineClock.capture(another))['reason'], 'different_user');
    elapsed += OfflineClock.maxAgeMs + 1;
    expect((await OfflineClock.capture(token))['reason'], 'expired_reference');
  });

  test('no reference or corrupt storage does not prevent offline work',
      () async {
    expect((await OfflineClock.capture(token))['source'], 'unverified');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('offline_clock_reference_v1', '{broken');
    expect((await OfflineClock.capture(token))['source'], 'unverified');
  });

  test('queued evidence is immutable when device time changes before upload',
      () async {
    await OfflineClock.synchronize('https://example.test/api', token);
    elapsed += 1000;
    final captured = await OfflineClock.capture(token);
    await CollectionQueueStorage.enqueue(
        {'event_time': captured, '_queue_user_id': 7});
    deviceMs -= const Duration(days: 3).inMilliseconds;
    elapsed += 100000;
    final queued = (await CollectionQueueStorage.getAll()).single;
    expect(queued['event_time'], captured);
    expect(queued['event_time']['delta_ms'], 1000);
  });

  test('enqueue during removal retains newly queued attendance', () async {
    await CollectionQueueStorage.enqueue({'id': 1});
    await Future.wait([
      CollectionQueueStorage.removeFirstN(1),
      CollectionQueueStorage.enqueue({'id': 2}),
      CollectionQueueStorage.enqueue({'id': 3}),
    ]);
    expect((await CollectionQueueStorage.getAll()).map((e) => e['id']), [2, 3]);
  });
}
