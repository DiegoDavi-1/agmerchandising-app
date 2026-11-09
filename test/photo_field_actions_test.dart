import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ag_merchandising/models/brand_field.dart';
import 'package:ag_merchandising/widgets/dynamic_field_widget.dart';

void main() {
  testWidgets('photo removal asks for confirmation and photo opens enlarged',
      (tester) async {
    dynamic lastValue = 'unchanged';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFieldWidget(
            field: BrandField(
              id: 1,
              brandId: 1,
              fieldType: 'photo',
              fieldLabel: 'Foto',
              fieldName: 'foto',
              displayOrder: 0,
            ),
            initialValue: '/tmp/nao_existe.jpg',
            onValueChanged: (_, value) => lastValue = value,
          ),
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Excluir foto?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(lastValue, 'unchanged');
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byType(ClipRRect).first);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    Navigator.of(tester.element(find.byType(InteractiveViewer))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(lastValue, isNull);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
