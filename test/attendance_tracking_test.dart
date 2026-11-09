import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ag_merchandising/services/api_service.dart';
import 'package:ag_merchandising/services/location_service.dart';

class FakeGps extends GeolocatorPlatform {
  final positions = StreamController<Position>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      positions.stream;
}

Position position({bool mocked = false}) => Position(
      latitude: -26.3044,
      longitude: -48.8487,
      timestamp: DateTime.now(),
      accuracy: 12,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: mocked,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('publishes once per minute only while check-in is open', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tracking-test'});
    await ApiService.init();
    final previous = GeolocatorPlatform.instance;
    final gps = FakeGps();
    GeolocatorPlatform.instance = gps;
    final tracker = LocationService();
    var open = true;
    final writes = <Map<String, dynamic>>[];
    try {
      await http.runWithClient(() async {
        await tracker.synchronize();
        expect(tracker.isTracking, true);
        gps.positions.add(position(mocked: true));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(writes, isEmpty);
        gps.positions.add(position());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(writes, hasLength(1));
        expect(writes.single['clock_entry_id'], 123);
        expect(writes.single['is_mock_location'], false);
        gps.positions.add(position());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(writes, hasLength(1));
        await Future<void>.delayed(const Duration(seconds: 60));
        gps.positions.add(position());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(writes, hasLength(2));
        final first = DateTime.parse(writes.first['observed_at'] as String);
        final second = DateTime.parse(writes.last['observed_at'] as String);
        expect(second.difference(first).inSeconds, greaterThanOrEqualTo(60));
        open = false;
        await tracker.synchronize();
        expect(tracker.isTracking, false);
        gps.positions.add(position());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(writes, hasLength(2));
      }, () => MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(jsonEncode({
            'success': true,
            'session': open ? {'id': 123, 'store_name': 'Test store'} : null
          }), 200);
        }
        writes.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{"success":true}', 200);
      }));
    } finally {
      await tracker.stopTracking();
      await gps.positions.close();
      GeolocatorPlatform.instance = previous;
    }
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('server checkout rejection stops GPS and publishing immediately', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tracking-test'});
    await ApiService.init();
    final previous = GeolocatorPlatform.instance;
    final gps = FakeGps();
    GeolocatorPlatform.instance = gps;
    final tracker = LocationService();
    var writes = 0;
    try {
      await http.runWithClient(() async {
        await tracker.synchronize();
        gps.positions.add(position());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(writes, 1);
        expect(tracker.isTracking, false);
        gps.positions.add(position());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(writes, 1);
      }, () => MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response('{"session":{"id":123}}', 200);
        }
        writes++;
        return http.Response(
            '{"tracking_stopped":true,"error":"Atendimento encerrado"}', 409);
      }));
    } finally {
      await tracker.stopTracking();
      await gps.positions.close();
      GeolocatorPlatform.instance = previous;
    }
  });
}
