// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ag_merchandising/main.dart';
import 'package:ag_merchandising/pages/terms_acceptance_page.dart';

void main() {
  testWidgets('App shows login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'terms_accepted_version': TermsAcceptance.version,
    });

    await tester.pumpWidget(const MyApp());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Image), findsWidgets);
    expect(find.widgetWithText(TextFormField, 'Login'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
