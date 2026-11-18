import 'dart:convert';
import 'dart:io';

import 'package:ag_merchandising/pages/dynamic_brand_collection_page.dart';
import 'package:ag_merchandising/pages/ponto_page.dart';
import 'package:ag_merchandising/services/api_service.dart';
import 'package:ag_merchandising/services/collection_draft_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoGps extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalGps = GeolocatorPlatform.instance;
  final key = CollectionDraftStorage.key(7, 31, 154);
  final request = <String, dynamic>{
    'data': {'observacao': 'trabalho preservado'},
    'latitude': -26.37,
    'longitude': -48.71,
    'requires_visit_clock': true,
    'event_time': {'source': 'unverified', 'device_ms': 123},
    'photo_job_ids': <String>[],
  };

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final font = await File(
            '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/roboto-regular.ttf')
        .readAsBytes();
    final assets = <String, Object>{
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold'])
        'Poppins-$weight.ttf': [
          {'asset': 'Poppins-$weight.ttf'}
        ],
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final name = utf8.decode(message!.buffer.asUint8List());
      if (name == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(assets);
      }
      if (name.startsWith('Poppins-') && name.endsWith('.ttf')) {
        return ByteData.sublistView(font);
      }
      return null;
    });
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GeolocatorPlatform.instance = _NoGps();
    FlutterSecureStorage.setMockInitialValues({
      'auth_token':
          'header.${base64Url.encode(utf8.encode('{"id":7}'))}.signature',
      'user_data': '{"id":7,"role":"user"}',
    });
    await ApiService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/connectivity'),
            (_) async => ['wifi']);
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalGps;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/connectivity'),
            null);
  });
  tearDownAll(() {
    GoogleFonts.config.allowRuntimeFetching = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: DynamicBrandCollectionPage(
          brandId: 31, brandName: 'BRF', storeId: 154),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'cancelled checkout keeps a saved locked attendance and never posts it again',
      (tester) async {
    await CollectionDraftStorage.save(
        key, {'observacao': 'trabalho preservado'},
        submissionId: 'a' * 32,
        submissionRequest: request,
        submissionResult: {
          'success': true,
          'collection_id': 99,
          'requires_clock_out': true,
          'clock_in_id': 12,
        });
    var posts = 0;
    await http.runWithClient(() async {
      await open(tester);
      expect(find.text('Salvar Coleta'), findsNothing);
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.text('Registrar saida'));
        await tester.pumpAndSettle();
        expect(find.byType(PontoPage), findsOneWidget);
        Navigator.of(tester.element(find.byType(PontoPage))).pop(false);
        await tester.pumpAndSettle();
        expect(find.text('Registrar saida'), findsOneWidget);
        expect(
            (await CollectionDraftStorage.loadSession(key))
                ?.submissionResult?['collection_id'],
            99);
      }
    },
        () => MockClient((req) async {
              if (req.method == 'POST') posts++;
              final path = req.url.path;
              if (path.endsWith('/visit-status')) {
                return http.Response(
                    '{"success":true,"is_open":true,"requires_check_in_out":true,"clock_in_id":12,"store_name":"Loja 50"}',
                    200);
              }
              if (path.endsWith('/today-stores')) {
                return http.Response('{"success":true,"stores":[]}', 200);
              }
              return http.Response('{"success":true,"data":[]}', 200);
            }));
    expect(posts, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await open(tester);
    expect(find.text('Registrar saida'), findsOneWidget);
    expect(find.text('Salvar Coleta'), findsNothing);
  });

  testWidgets(
      'uncertain submission retries its exact persisted request before checkout',
      (tester) async {
    await CollectionDraftStorage.save(
        key, {'observacao': 'trabalho preservado'},
        submissionId: 'b' * 32, submissionRequest: request);
    final posts = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await open(tester);
      expect(find.text('Tentar envio novamente'), findsOneWidget);
      await tester.tap(find.text('Tentar envio novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Tentar envio novamente'), findsOneWidget);
      expect((await CollectionDraftStorage.loadSession(key))?.submissionRequest,
          request);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tentar envio novamente'));
      await tester.pumpAndSettle();
      expect(find.byType(PontoPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(PontoPage))).pop(false);
      await tester.pumpAndSettle();
      expect(find.text('Registrar saida'), findsOneWidget);
      expect(find.text('Salvar Coleta'), findsNothing);
    },
        () => MockClient((req) async {
              if (req.method == 'POST') {
                expect(req.url.path, '/api/collections');
                posts.add(jsonDecode(req.body) as Map<String, dynamic>);
                if (posts.length == 1) {
                  throw const SocketException('Response lost');
                }
                return http.Response(
                    '{"success":true,"collection_id":99,"requires_clock_out":true,"clock_in_id":12}',
                    200);
              }
              if (req.url.path.contains('/fields')) {
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'fields': [
                        {
                          'id': 1,
                          'brand_id': 31,
                          'field_name': 'observacao',
                          'field_type': 'text',
                          'field_label': 'Observacao',
                          'display_order': 0
                        }
                      ]
                    }),
                    200);
              }
              if (req.url.path.endsWith('/visit-status')) {
                return http.Response(
                    '{"success":true,"is_open":true,"requires_check_in_out":true,"clock_in_id":12}',
                    200);
              }
              return http.Response(
                  '{"success":true,"data":[],"stores":[]}', 200);
            }));
    expect(posts.length, 2);
    expect(posts[0], posts[1]);
    expect(posts[0]['client_submission_id'], 'b' * 32);
    expect(posts[0]['event_time'], request['event_time']);
  });
}
