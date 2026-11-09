import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ag_merchandising/pages/portal_messages.dart';
import 'package:ag_merchandising/pages/supervisor_page.dart';
import 'package:ag_merchandising/pages/supervisor_portal_sections.dart';
import 'package:ag_merchandising/pages/role_home_page.dart';
import 'package:ag_merchandising/services/api_service.dart';

void main() {
  testWidgets('supervisor enters the dedicated portal, not promoter menu',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoleHomePage(
        isAuthenticated: () => true,
        loadUser: () async => {'role': 'supervisor'},
        supervisorHome: const Text('Portal da equipe'),
        promoterHome: const Text('Menu do promotor'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Portal da equipe'), findsOneWidget);
    expect(find.text('Menu do promotor'), findsNothing);
  });

  testWidgets('promoter enters execution menu, not supervisor portal',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoleHomePage(
        isAuthenticated: () => true,
        loadUser: () async => {'role': 'promoter'},
        supervisorHome: const Text('Portal da equipe'),
        promoterHome: const Text('Menu do promotor'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Menu do promotor'), findsOneWidget);
    expect(find.text('Portal da equipe'), findsNothing);
  });

  testWidgets('missing role shows error instead of guessing promoter',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoleHomePage(
        isAuthenticated: () => true,
        loadUser: () async => {},
        supervisorHome: const Text('Portal da equipe'),
        promoterHome: const Text('Menu do promotor'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Perfil indisponível'), findsOneWidget);
    expect(find.text('Portal da equipe'), findsNothing);
    expect(find.text('Menu do promotor'), findsNothing);
  });

  testWidgets('unsupported role cannot enter the promoter app', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoleHomePage(
        isAuthenticated: () => true,
        loadUser: () async => {'role': 'admin'},
        supervisorHome: const Text('Portal da equipe'),
        promoterHome: const Text('Menu do promotor'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('não tem acesso'), findsOneWidget);
    expect(find.text('Menu do promotor'), findsNothing);
  });

  testWidgets('role destination stays hidden until profile loads',
      (tester) async {
    final user = Completer<Map<String, dynamic>?>();
    await tester.pumpWidget(MaterialApp(
      home: RoleHomePage(
        isAuthenticated: () => true,
        loadUser: () => user.future,
        supervisorHome: const Text('Portal da equipe'),
        promoterHome: const Text('Menu do promotor'),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Menu do promotor'), findsNothing);
    user.complete({'role': 'supervisor'});
    await tester.pumpAndSettle();
    expect(find.text('Portal da equipe'), findsOneWidget);
  });

  test('photo URLs resolve uploads against the API origin', () {
    expect(ApiService.resolvePhotoUrl('/uploads/photo.jpg'),
        'https://merchhubapp.com/uploads/photo.jpg');
    expect(ApiService.resolvePhotoUrl('https://cdn.example.com/photo.jpg'),
        'https://cdn.example.com/photo.jpg');
    expect(ApiService.resolvePhotoUrl(null), isNull);
    expect(ApiService.resolvePhotoUrl(''), isNull);
  });

  testWidgets('portal photo loads the resolved URL, not the relative path',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PortalPhoto(url: '/uploads/photo.jpg', height: 100)),
    ));
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url,
        'https://merchhubapp.com/uploads/photo.jpg');
  });

  test('portal dates use the API date format', () {
    expect(portalDate(DateTime(2026, 2, 3)), '2026-02-03');
  });

  test('promoter progress supports percent and fractional API values', () {
    expect(
        promoterProgress({'planned': 4, 'completed': 3, 'progress': 75}), 0.75);
    expect(promoterProgress({'planned': 4, 'completed': 3, 'progress': 0.75}),
        0.75);
    expect(promoterProgress({'planned': 4, 'completed': 3}), 0.75);
    expect(promoterProgress({'planned': 0, 'completed': 0}), 0);
    expect(promoterProgress({'progress': 150}), 1);
  });

  testWidgets('message notice is visible and opens the inbox on tap',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PromoterMessageNotice(
          count: 2,
          onOpen: () => opened = true,
        ),
      ),
    ));

    expect(find.text('2 novas mensagens da gestão'),
        findsOneWidget);
    expect(find.text('Toque para responder perguntas ou ver avisos'), findsOneWidget);
    await tester.tap(find.byType(PromoterMessageNotice));
    expect(opened, isTrue);
  });

  testWidgets('inbox GET does not mark read; explicit action POSTs and reloads',
      (tester) async {
    var unreadCount = 1;
    var reads = 0;
    var fetches = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PortalMessages(
          supervisor: false,
          fetchPromoterMessages: () async {
            fetches++;
            return {
              'success': true,
              'unreadCount': unreadCount,
              'data': [
                {
                  'id': 42,
                  'type': 'request',
                  'message': 'Conferir exposição',
                  'readAt': unreadCount == 0 ? '2026-09-28T17:00:00Z' : null,
                  'replies': [],
                },
              ],
            };
          },
          markPromoterMessageRead: (id) async {
            expect(id, 42);
            reads++;
            unreadCount = 0;
            return {'success': true};
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(fetches, 1);
    expect(reads, 0);
    expect(find.text('Você tem 1 mensagem(ns) não lida(s)'), findsOneWidget);
    expect(find.text('Nova'), findsOneWidget);
    await tester.tap(find.text('Lida'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(fetches, 2);
    expect(find.textContaining('mensagem(ns) não lida(s)'), findsNothing);
    expect(find.text('Lida'), findsNothing);
    expect(find.text('Responder Pergunta'), findsOneWidget);
  });

  testWidgets('failed read keeps message unread and surfaces error',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PortalMessages(
          supervisor: false,
          fetchPromoterMessages: () async => {
            'success': true,
            'unreadCount': 1,
            'data': [
              {
                'id': 7,
                'type': 'notice',
                'message': 'Aviso',
                'readAt': null,
                'replies': [],
              },
            ],
          },
          markPromoterMessageRead: (id) async => throw Exception('offline'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lida'));
    await tester.pumpAndSettle();
    expect(find.text('Você tem 1 mensagem(ns) não lida(s)'), findsOneWidget);
    expect(find.text('Lida'), findsOneWidget);
    expect(find.textContaining('Não foi possível marcar como lida'),
        findsOneWidget);
  });
}
