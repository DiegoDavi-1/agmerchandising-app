import 'package:ag_merchandising/pages/my_day_page.dart';
import 'package:ag_merchandising/pages/store_expiries_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
