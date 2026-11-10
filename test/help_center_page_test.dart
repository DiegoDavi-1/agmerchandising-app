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
    expect(find.text('Assistir no YouTube'), findsWidgets);
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

  testWidgets('treinamentos abrem os sete vídeos publicados', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(MaterialApp(
      home: TrainingsPage(openVideo: (uri) async {
        opened.add(uri);
        return true;
      }),
    ));
    const titles = [
      '01 - Primeiros passos no aplicativo e no portal',
      '02 - Como realizar um atendimento',
      '03 - Como registrar entrada e saída',
      '04 - Como enviar fotos e responder auditorias',
      '05 - Mensagens e orientações da equipe',
      '06.1 - Minha rota: conferir e solicitar alterações',
      '06.2 - Fale com a equipe: ajuda, respostas e bugs',
    ];
    for (final title in titles) {
      await tester.scrollUntilVisible(find.text(title), 150);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }
    expect(opened.map((uri) => uri.queryParameters['v']).toList(), [
      'A4QlgutR600',
      'YoalW_1diYc',
      'CFMr4b9JWCM',
      'TByun9txw5E',
      '4Yy4BmINoPI',
      'CM8Jsix-aME',
      'G32NbnndzIs',
    ]);
    expect(
        opened.every(
            (uri) => uri.scheme == 'https' && uri.host == 'www.youtube.com'),
        isTrue);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  for (final throwsError in [false, true]) {
    testWidgets('treinamento informa falha ao abrir: $throwsError',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TrainingsPage(openVideo: (_) async {
          if (throwsError) throw StateError('launcher unavailable');
          return false;
        }),
      ));
      await tester
          .tap(find.text('01 - Primeiros passos no aplicativo e no portal'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Não foi possível abrir o vídeo.'),
          findsOneWidget);
    });
  }
}
