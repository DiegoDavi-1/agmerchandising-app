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

    expect(find.text('2 novas mensagens da gestão'), findsOneWidget);
    expect(find.text('Toque para responder perguntas ou ver avisos'),
        findsOneWidget);
    await tester.tap(find.byType(PromoterMessageNotice));
    expect(opened, isTrue);
  });

  testWidgets('visible messages display and confirm without a tap or reload',
      (tester) async {
    final pendingRead = Completer<Map<String, dynamic>>();
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
              'unreadCount': 2,
              'data': [
                {
                  'id': 42,
                  'type': 'request',
                  'message':
                      'Conferir exposição\n${List.filled(50, 'Detalhe').join('\n')}',
                  'replies': [],
                },
                {
                  'id': 43,
                  'type': 'notice',
                  'message': 'Segundo aviso',
                  'replies': [],
                },
              ],
            };
          },
          markPromoterMessageRead: (id) async {
            reads++;
            if (id == 42) return pendingRead.future;
            expect(id, 43);
            return {'success': true};
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(fetches, 1);
    expect(reads, 1);
    expect(find.text('Você tem 2 mensagem(ns) não lida(s)'), findsOneWidget);
    final visibleMessage = find.textContaining('Conferir exposição');
    expect(visibleMessage, findsOneWidget);
    expect(tester.getTopLeft(visibleMessage).dy,
        lessThan(tester.getBottomLeft(find.byType(ListView)).dy));
    expect(find.text('Abrir mensagem'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -70));
    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(reads, 1);
    pendingRead.complete({'success': true});
    await tester.pumpAndSettle();
    expect(fetches, 1);
    expect(find.text('Você tem 1 mensagem(ns) não lida(s)'), findsOneWidget);
    expect(find.text('Segundo aviso').hitTestable(), findsNothing);
    expect(find.text('Lida'), findsNothing);
    expect(find.text('Responder Pergunta').hitTestable(), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Segundo aviso').hitTestable(), findsOneWidget);
    expect(find.textContaining('mensagem(ns) não lida(s)'), findsNothing);
  });

  testWidgets('failed read stays unread and retries on returning to view',
      (tester) async {
    var attempts = 0;
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
                'message': 'Aviso\n${List.filled(50, 'Detalhe').join('\n')}',
                'readAt': null,
                'replies': [],
              },
            ],
          },
          markPromoterMessageRead: (id) async {
            if (++attempts == 1) throw Exception('offline');
            return {'success': true};
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Você tem 1 mensagem(ns) não lida(s)'), findsOneWidget);
    expect(find.text('Nova'), findsOneWidget);
    expect(find.textContaining('Não foi possível registrar a leitura'),
        findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    await tester.drag(find.byType(ListView), const Offset(0, 260));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Nova'), findsNothing);
  });
}
