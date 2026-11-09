import 'package:ag_merchandising/widgets/non_visit_reschedule_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(
      WidgetTester tester, Future<void> Function(DateTime) submit) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => NonVisitRescheduleDialog(onSubmit: submit),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> selectDate(WidgetTester tester) async {
    await tester.tap(find.text('Escolher nova data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('rescheduling is optional and cannot be sent without a date',
      (tester) async {
    var calls = 0;
    await open(tester, (_) async {
      calls++;
    });
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Enviar para aprovação'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(NonVisitRescheduleDialog), findsNothing);
  });

  testWidgets('selected future date is sent for approval', (tester) async {
    DateTime? submitted;
    await open(tester, (date) async {
      submitted = date;
    });
    await selectDate(tester);
    await tester.tap(find.text('Enviar para aprovação'));
    await tester.pumpAndSettle();
    expect(submitted, isNotNull);
    expect(submitted!.isAfter(DateUtils.dateOnly(DateTime.now())), isTrue);
    expect(find.byType(NonVisitRescheduleDialog), findsNothing);
  });

  testWidgets('submission failure is visible and permits retry',
      (tester) async {
    var attempts = 0;
    await open(tester, (_) async {
      if (++attempts == 1) throw Exception('Sem conexão');
    });
    await selectDate(tester);
    await tester.tap(find.text('Enviar para aprovação'));
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão'), findsOneWidget);
    expect(find.byType(NonVisitRescheduleDialog), findsOneWidget);
    await tester.tap(find.text('Enviar para aprovação'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(NonVisitRescheduleDialog), findsNothing);
  });

  testWidgets('schedule conflict warns the promoter and keeps the date picker available',
      (tester) async {
    const warning = 'Esta loja e marca já estão agendadas ou têm uma remarcação '
        'solicitada para esse dia. Escolha outra data.';
    await open(tester, (_) async => throw Exception(warning));
    await selectDate(tester);
    await tester.tap(find.text('Enviar para aprovação'));
    await tester.pumpAndSettle();
    expect(find.text(warning), findsOneWidget);
    expect(find.byType(NonVisitRescheduleDialog), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull);
  });
}
