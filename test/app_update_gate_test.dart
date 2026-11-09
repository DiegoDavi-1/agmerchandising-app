import 'package:ag_merchandising/widgets/app_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(AppUpdateGate Function(Widget child) gate) => MaterialApp(
      builder: (context, child) => gate(child!),
      home: const Scaffold(body: Text('Tela do app')),
    );

void main() {
  testWidgets('versão nova na Play bloqueia o app e o botão inicia a atualização',
      (tester) async {
    var starts = 0;
    var storeOpens = 0;
    await tester.pumpWidget(_app((child) => AppUpdateGate(
          checker: () async => UpdateCheckResult.required,
          starter: () async {
            starts++;
            return true;
          },
          storeOpener: () async {
            storeOpens++;
            return true;
          },
          child: child,
        )));
    await tester.pumpAndSettle();

    expect(find.text('Atualização obrigatória'), findsOneWidget);
    expect(find.text('Atualizar agora'), findsOneWidget);
    expect(
        tester
            .widgetList<ExcludeSemantics>(find.byType(ExcludeSemantics))
            .any((w) => w.excluding),
        isTrue);

    await tester.tap(find.text('Atualizar agora'));
    await tester.pumpAndSettle();
    expect(starts, 1);
    expect(storeOpens, 0);
    expect(find.text('Atualização obrigatória'), findsOneWidget);
  });

  testWidgets('sem fluxo da Play abre a loja e mostra erro se nada abrir',
      (tester) async {
    var storeOpens = 0;
    await tester.pumpWidget(_app((child) => AppUpdateGate(
          checker: () async => UpdateCheckResult.required,
          starter: () async => throw Exception('play indisponível'),
          storeOpener: () async {
            storeOpens++;
            return false;
          },
          child: child,
        )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atualizar agora'));
    await tester.pumpAndSettle();

    expect(storeOpens, 1);
    expect(find.textContaining('Abra a Play Store'), findsOneWidget);
  });

  testWidgets('sem atualização ou sem resposta da Play o app abre normalmente',
      (tester) async {
    for (final result in [UpdateCheckResult.notRequired, UpdateCheckResult.unknown]) {
      await tester.pumpWidget(_app((child) => AppUpdateGate(
            key: UniqueKey(),
            checker: () async => result,
            child: child,
          )));
      await tester.pumpAndSettle();
      expect(find.text('Tela do app'), findsOneWidget);
      expect(find.text('Atualização obrigatória'), findsNothing);
    }
  });

  testWidgets('consulta lenta da Play não prende o promotor na abertura',
      (tester) async {
    await tester.pumpWidget(_app((child) => AppUpdateGate(
          checker: () => Future.delayed(
              const Duration(seconds: 30), () => UpdateCheckResult.required),
          initialTimeout: const Duration(seconds: 1),
          child: child,
        )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Tela do app'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('ao voltar para o app, nova versão publicada passa a bloquear',
      (tester) async {
    var result = UpdateCheckResult.notRequired;
    await tester.pumpWidget(_app((child) => AppUpdateGate(
          checker: () async => result,
          child: child,
        )));
    await tester.pumpAndSettle();
    expect(find.text('Atualização obrigatória'), findsNothing);

    result = UpdateCheckResult.required;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Atualização obrigatória'), findsOneWidget);

    // Falha temporária na consulta não desbloqueia.
    result = UpdateCheckResult.unknown;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Atualização obrigatória'), findsOneWidget);
  });
}
