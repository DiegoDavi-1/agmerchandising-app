import 'dart:convert';

import 'package:ag_merchandising/pages/route_change_request_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _options = {
  'stores': [
    {'id': 1, 'chain': 'Koch', 'store_name': 'Centro', 'city': 'Itajai'},
    {'id': 2, 'chain': 'Koch', 'store_name': 'Praia'},
  ],
  'brands': [
    {'id': 10, 'name': 'Marca Alfa'},
    {'id': 20, 'name': 'Marca Beta'},
  ],
  'assignments': [
    {
      'store_id': 1,
      'brand_id': 10,
      'weekdays': [5, 1]
    },
    {
      'store_id': 1,
      'brand_id': 20,
      'weekdays': [3]
    },
    {
      'store_id': 2,
      'brand_id': 10,
      'weekdays': [2]
    },
  ],
};

MockClient _client(List<Map<String, dynamic>> submissions,
    {bool empty = false}) {
  return MockClient((request) async {
    if (request.method == 'POST') {
      submissions.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({'success': true}), 201);
    }
    return http.Response(
        jsonEncode({
          'success': true,
          'data': request.url.path.endsWith('/options')
              ? {..._options, if (empty) 'assignments': []}
              : submissions
                  .map((item) => {
                        ...item,
                        'status': 'pending',
                        'brand_name': 'Marca Alfa',
                        'chain': 'Koch',
                        'store_name': 'Centro',
                      })
                  .toList(),
        }),
        200);
  });
}

void main() {
  test('nomes de loja nao repetem rede nem numero com zeros a esquerda', () {
    expect(
        formatRouteStoreLabel({
          'chain': 'Koch',
          'store_number': 1,
          'store_name': 'Loja 01 - Komprão Koch',
        }),
        'Loja 01 - Komprão Koch');
    expect(
        formatRouteStoreLabel({
          'chain': 'Koch',
          'store_number': 12,
          'store_name': 'Centro',
        }),
        'Koch · Loja 12 · Centro');
    expect(formatRouteStoreLabel({'id': 8}), 'Loja 8');
  });

  test('lojas seguem ordem numerica e preservam nomes legados', () {
    for (final includeNumber in [true, false]) {
      final stores = [
        for (final number in [100, 11, 2, 10, 1])
          <String, dynamic>{
            'chain': 'Koch',
            if (includeNumber) 'store_number': number,
            'store_name': 'Loja $number - Koch',
          },
      ]..sort(compareRouteStores);
      expect(stores.map((store) => store['store_name']),
          [1, 2, 10, 11, 100].map((number) => 'Loja $number - Koch'));
    }
  });

  testWidgets('agrupa por loja, mostra marcas/dias e filtra a rota',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: RouteChangeRequestPage()));
      await tester.pumpAndSettle();
      expect(find.text('Koch · Centro'), findsOneWidget);
      expect(find.text('Marca Beta'), findsOneWidget);
      expect(find.text('Dias de atendimento: Seg, Sex'), findsOneWidget);
      expect(find.text('Dias de atendimento: Qua'), findsOneWidget);
      expect(find.text('Enviar solicitação'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'Beta');
      await tester.pumpAndSettle();
      expect(find.text('Koch · Centro'), findsOneWidget);
      expect(find.text('Marca Alfa'), findsNothing);
      expect(find.text('Koch · Praia'), findsNothing);
      await tester.tap(find.text('Alterar dias'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voltar aos atendimentos'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          'Beta');
      expect(find.text('Marca Alfa'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'inexistente');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma loja ou marca encontrada para essa busca.'),
          findsOneWidget);
    }, () => _client([]));
  });

  testWidgets('alterar preenche dias e envia pedido sem modificar a rota',
      (tester) async {
    final submissions = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: RouteChangeRequestPage()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Alterar dias').first);
      await tester.tap(find.text('Alterar dias').first);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FilterChip>(find.widgetWithText(FilterChip, 'Seg'))
              .selected,
          isTrue);
      expect(
          tester
              .widget<FilterChip>(find.widgetWithText(FilterChip, 'Sex'))
              .selected,
          isTrue);
      await tester.tap(find.widgetWithText(FilterChip, 'Qua'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Enviar solicitação'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar solicitação'));
      await tester.pumpAndSettle();
      expect(submissions.single, {
        'store_id': 1,
        'brand_id': 10,
        'action': 'change',
        'weekdays': [1, 3, 5],
      });
      expect(find.text('Dias de atendimento: Seg, Sex'), findsOneWidget);
    }, () => _client(submissions));
  });

  testWidgets('remover permite solicitar todos os dias', (tester) async {
    final submissions = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: RouteChangeRequestPage()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Remover').first);
      await tester.tap(find.text('Remover').first);
      await tester.pumpAndSettle();
      expect(
          tester
              .widgetList<FilterChip>(find.byType(FilterChip))
              .every((chip) => !chip.selected),
          isTrue);
      await tester.ensureVisible(find.text('Enviar solicitação'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar solicitação'));
      await tester.pumpAndSettle();
      expect(submissions.single['action'], 'remove');
      expect(submissions.single['weekdays'], isEmpty);
      expect(find.text('Dias de atendimento: Seg, Sex'), findsOneWidget);
      await tester.ensureVisible(find.text('Adicionar atendimento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar atendimento'));
      await tester.pumpAndSettle();
      expect(find.text('Em quais dias você atende?'), findsNothing);
      expect(find.text('Loja'), findsOneWidget);
      expect(find.text('Marca'), findsOneWidget);
    }, () => _client(submissions));
  });

  testWidgets('adicionar exige dias e aguarda analise sem modificar a rota',
      (tester) async {
    final submissions = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: RouteChangeRequestPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar atendimento'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Loja').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Koch · Centro').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Marca').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marca Alfa'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Enviar solicitação'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar solicitação'));
      await tester.pumpAndSettle();
      expect(submissions, isEmpty);
      expect(
          find.text('Selecione pelo menos um dia da semana.'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Seg'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Seg'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Enviar solicitação'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar solicitação'));
      await tester.pumpAndSettle();
      expect(submissions.single, {
        'store_id': 1,
        'brand_id': 10,
        'action': 'add',
        'weekdays': [1],
      });
      expect(find.text('Dias de atendimento: Seg, Sex'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Aguardando análise'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Aguardando análise'), findsOneWidget);
    }, () => _client(submissions));
  });

  testWidgets('rota vazia oferece inclusao', (tester) async {
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: RouteChangeRequestPage()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nenhum atendimento semanal cadastrado.'),
          findsOneWidget);
      expect(find.text('Adicionar atendimento'), findsOneWidget);
    }, () => _client([], empty: true));
  });

  testWidgets('falha de carregamento permite tentar novamente', (tester) async {
    var failing = true;
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: RouteChangeRequestPage()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Rota indisponivel'), findsOneWidget);
      expect(find.text('Adicionar atendimento'), findsNothing);
      failing = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Koch · Centro'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (failing) {
                return http.Response(
                    jsonEncode(
                        {'success': false, 'error': 'Rota indisponivel'}),
                    400);
              }
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'data':
                        request.url.path.endsWith('/options') ? _options : [],
                  }),
                  200);
            }));
  });
}
