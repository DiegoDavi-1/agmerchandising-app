import 'package:ag_merchandising/pages/help_center_page.dart';
import 'package:ag_merchandising/pages/route_change_request_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('suporte separa cada assunto em sua própria tela',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HelpCenterPage(showRouteChange: true)),
    );

    expect(find.text('Suporte'), findsOneWidget);
    expect(find.text('Conferir meus atendimentos'), findsOneWidget);
    expect(find.text('Falar com o suporte'), findsOneWidget);
    expect(find.text('Relatar bug'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Treinamentos'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Manual de uso'), findsOneWidget);
    expect(find.text('Treinamentos'), findsOneWidget);

    await tester.tap(find.text('Relatar bug'));
    await tester.pumpAndSettle();
    expect(find.text('Enviar relato'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Treinamentos'));
    await tester.pumpAndSettle();
    expect(find.text('Vídeo em preparação'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manual de uso'));
    await tester.pumpAndSettle();
    expect(find.text('1. Entre e confira seu dia'), findsOneWidget);
  });

  testWidgets('supervisor não vê a solicitação de alteração de rota',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HelpCenterPage(showRouteChange: false)),
    );
    expect(find.text('Conferir meus atendimentos'), findsNothing);
    expect(find.text('Falar com o suporte'), findsOneWidget);
  });

  test('dias da semana são exibidos a partir de segunda-feira', () {
    expect(formatWeekdays([5, 1, 3]), 'Seg, Qua, Sex');
    expect(formatWeekdays([0, 6]), 'Sáb, Dom');
    expect(formatWeekdays([]), '—');
  });
}
