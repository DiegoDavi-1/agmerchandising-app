import 'dart:convert';
import 'dart:io';

import 'package:ag_merchandising/core/photo_quality.dart';
import 'package:ag_merchandising/services/photo_capture_time.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CountingPicker extends ImagePicker {
  int calls = 0;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PhotoCaptureTime.isOnline = () async => true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.merchhub/offline_clock'),
            (_) async => {
                  'boot_id': '10',
                  'elapsed_ms': 1000,
                  'device_ms': 1800000000000
                });
  });
  tearDown(() {
    PhotoCaptureTime.clientFactory = http.Client.new;
    PhotoCaptureTime.isOnline = () async => true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.merchhub/offline_clock'), null);
  });

  testWidgets('camera opens offline without falsely verifying its time',
      (tester) async {
    PhotoCaptureTime.isOnline = () async => false;
    final picker = CountingPicker();
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    expect(
        await tester.runAsync(
            () => PhotoQuality.captureChecked(context, picker, 'Foto')),
        isNull);
    expect(picker.calls, 1);
  });

  test('the server interval is bound to the exact captured file', () async {
    final folder = await Directory.systemTemp.createTemp('photo-time-');
    addTearDown(() => folder.delete(recursive: true));
    final photo = File('${folder.path}${Platform.pathSeparator}photo.jpg');
    await photo.writeAsBytes([1, 2, 3]);
    var finishCount = 0;
    PhotoCaptureTime.clientFactory = () => MockClient((request) async {
          if (request.url.path.endsWith('/start')) {
            return http.Response(
                jsonEncode({'success': true, 'token': 'start-token'}), 200);
          }
          finishCount++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['token'], 'start-token');
          expect(body['sha256'], sha256.convert([1, 2, 3]).toString());
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response(
              jsonEncode({'success': true, 'proof': 'server-proof'}), 200);
        });

    final token = await PhotoCaptureTime.start();
    await Future.wait([
      PhotoCaptureTime.seal(photo, token),
      PhotoCaptureTime.seal(photo, token),
    ]);
    expect(finishCount, 1);
    expect(
        await PhotoCaptureTime.proofFile(photo).readAsString(), 'server-proof');
  });

  test('offline photo metadata is persisted locally and recovery is unverified',
      () async {
    PhotoCaptureTime.isOnline = () async => false;
    final folder =
        await Directory.systemTemp.createTemp('offline-photo-time-');
    addTearDown(() => folder.delete(recursive: true));
    final photo = File('${folder.path}${Platform.pathSeparator}photo.jpg');
    await photo.writeAsBytes([1, 2, 3]);
    final token = await PhotoCaptureTime.start();
    await PhotoCaptureTime.seal(photo, token, recovered: true);
    final evidence =
        jsonDecode(await PhotoCaptureTime.proofFile(photo).readAsString());
    expect(evidence['digest'], sha256.convert([1, 2, 3]).toString());
    expect(evidence['end']['source'], 'unverified');
    expect(evidence['end']['reason'], 'interrupted_capture');
  });
}
