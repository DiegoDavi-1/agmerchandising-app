import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ag_merchandising/pages/terms_acceptance_page.dart';

void main() {
  testWidgets('terms can be accepted with large font on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: TermsAcceptancePage(onAccepted: () {}),
    ));

    expect(tester.takeException(), isNull);
    final checkbox = find.byType(CheckboxListTile);
    await tester.scrollUntilVisible(checkbox, 200);
    await tester.tap(checkbox);
    await tester.pump();
    final button = find.widgetWithText(FilledButton, 'Continuar');
    await tester.scrollUntilVisible(button, 200);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });
}
