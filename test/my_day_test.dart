import 'dart:convert';

import 'package:ag_merchandising/pages/my_day_page.dart';
import 'package:ag_merchandising/pages/store_expiries_page.dart';
import 'package:ag_merchandising/services/api_service.dart';
import 'package:ag_merchandising/services/schedule_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('weekly schedule', () {
    final schedule = {
      'success': true,
      'days': [
        {
          'date': '2026-11-13',
          'assignments': [
            {'store_id': 189, 'brand_id': 42, 'is_completed': false}
          ]
        }
      ]
    };

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'schedule-test'});
      await ApiService.init();
    });

    test('retries DNS failures and preserves the returned route', () async {
      var attempts = 0;
      final result = await http.runWithClient(
          ScheduleService.getWeekSchedule,
          () => MockClient((request) async {
                expect(request.url.path, '/api/schedule/week');
                expect(request.headers['Authorization'], 'Bearer schedule-test');
                attempts++;
                if (attempts == 1) {
                  throw http.ClientException(
                      "Failed host lookup: 'merchhubapp.com'", request.url);
                }
                return http.Response(jsonEncode(schedule), 200);
              }));
      expect(attempts, 2);
      expect(result, schedule);
    });

    test('reports persistent DNS failure without inventing an empty route',
        () async {
      var attempts = 0;
      await expectLater(
          http.runWithClient(
              ScheduleService.getWeekSchedule,
              () => MockClient((request) async {
                    attempts++;
                    throw http.ClientException(
                        "Failed host lookup: 'merchhubapp.com'", request.url);
                  })),
          throwsA(predicate<Object>((error) =>
              error.toString().contains('conexão') &&
              !error.toString().contains('merchhubapp.com'))));
      expect(attempts, 4);
    });

    test('preserves access errors without retrying', () async {
      var attempts = 0;
      await expectLater(
          http.runWithClient(
              ScheduleService.getWeekSchedule,
              () => MockClient((request) async {
                    attempts++;
                    return http.Response('{"error":"Acesso negado"}', 403);
                  })),
          throwsA(predicate<Object>(
              (error) => error.toString().contains('Acesso negado'))));
      expect(attempts, 1);
    });

    test('renews the session before retrying with the updated token', () async {
      FlutterSecureStorage.setMockInitialValues(
          {'auth_token': 'expired', 'refresh_token': 'refresh-test'});
      await ApiService.init();
      var reads = 0, refreshes = 0;
      final result = await http.runWithClient(
          ScheduleService.getWeekSchedule,
          () => MockClient((request) async {
                if (request.url.path == '/api/auth/refresh') {
                  refreshes++;
                  return http.Response(
                      '{"success":true,"token":"renewed","refreshToken":"next-refresh"}',
                      200);
                }
                reads++;
                if (reads == 1) {
                  return http.Response('{"error":"Token expirado"}', 401);
                }
                expect(request.headers['Authorization'], 'Bearer renewed');
                return http.Response(jsonEncode(schedule), 200);
              }));
      expect(result, schedule);
      expect(reads, 2);
      expect(refreshes, 1);
    });

    test('stops when the expired session cannot be renewed', () async {
      var attempts = 0;
      await expectLater(
          http.runWithClient(
              ScheduleService.getWeekSchedule,
              () => MockClient((request) async {
                    attempts++;
                    return http.Response('{"error":"Token expirado"}', 401);
                  })),
          throwsA(predicate<Object>(
              (error) => error.toString().contains('Token expirado'))));
      expect(attempts, 1);
      expect(ApiService.isAuthenticated(), false);
    });
  });

  group('DayProgress', () {
    test('conta atendimentos concluídos e pendentes do dia', () {
      final day = DayProgress.fromJson({
        'name': 'Segunda-feira',
        'date': '2026-09-28',
        'is_today': true,
        'assignments': [
          {'is_completed': true},
          {'is_completed': false},
          {'is_completed': true},
        ],
      });
      expect(day.total, 3);
      expect(day.done, 2);
      expect(day.pending, 1);
      expect(day.ratio, closeTo(2 / 3, 0.0001));
      expect(day.isToday, isTrue);
    });

    test('dia sem atendimentos não gera divisão por zero', () {
      final day = DayProgress.fromJson({'name': 'Domingo', 'date': '2026-09-27'});
      expect(day.total, 0);
      expect(day.ratio, 0);
    });
  });

  group('StoreExpiriesPage.daysUntil', () {
    final now = DateTime(2026, 9, 29, 15, 30);
    test('mesmo dia é zero', () {
      expect(StoreExpiriesPage.daysUntilForTest('2026-09-29', now), 0);
    });
    test('datas futuras e vencidas', () {
      expect(StoreExpiriesPage.daysUntilForTest('2026-10-06', now), 7);
      expect(StoreExpiriesPage.daysUntilForTest('2026-09-27', now), -2);
    });
  });
}
