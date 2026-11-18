import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ag_merchandising/models/brand_field.dart';
import 'package:ag_merchandising/widgets/dynamic_field_widget.dart';

void main() {
  testWidgets('queued photo is replaced by its uploaded URL on parent update',
      (tester) async {
    var photo = '/tmp/pending.jpg';
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        update = setState;
        return Scaffold(
            body: DynamicFieldWidget(
          field: BrandField(
              id: 1,
              brandId: 30,
              fieldType: 'photo',
              fieldLabel: 'Foto',
              fieldName: 'foto',
              displayOrder: 0),
          initialValue: photo,
          onValueChanged: (_, __) {},
        ));
      }),
    ));
    update(() => photo = '/uploads/synced.jpg');
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image).first);
    expect((image.image as ResizeImage).imageProvider, isA<NetworkImage>());
  });

  testWidgets(
      'smaller remove control sits at top right with a large touch area',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicFieldWidget(
          field: BrandField(
            id: 1,
            brandId: 1,
            fieldType: 'photo',
            fieldLabel: 'Foto',
            fieldName: 'foto',
            displayOrder: 0,
          ),
          initialValue: '/tmp/nao_existe.jpg',
          onValueChanged: (_, __) {},
        ),
      ),
    ));

    final preview = find.byType(ClipRRect).first;
    final remove = find.byTooltip('Remover foto');
    expect(tester.getSize(preview), const Size(128, 128));
    expect(tester.getSize(remove), const Size(48, 48));
    final previewRect = tester.getRect(preview);
    final removeRect = tester.getRect(remove);
    expect(previewRect.contains(removeRect.topLeft), isTrue);
    expect(removeRect.topRight, previewRect.topRight);

    final visibleButton = find.descendant(
      of: remove,
      matching: find.byType(Container),
    );
    expect(tester.getSize(visibleButton), const Size(24, 24));
    expect(tester.getRect(visibleButton).topRight, previewRect.topRight);
    expect(tester.getSize(find.byIcon(Icons.close)), const Size(16, 16));

    await tester.tapAt(removeRect.bottomLeft + const Offset(2, -2));
    await tester.pumpAndSettle();
    expect(find.text('Excluir foto?'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('removing a selected photo preserves the others and input list',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final original = ['/tmp/primeira.jpg', '/tmp/segunda.jpg'];
    dynamic lastValue;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicFieldWidget(
          field: BrandField(
            id: 1,
            brandId: 1,
            fieldType: 'photo',
            fieldLabel: 'Fotos',
            fieldName: 'fotos',
            fieldConfig: BrandFieldConfig(allowMultiple: true, maxPhotos: 5),
            displayOrder: 0,
          ),
          initialValue: original,
          onValueChanged: (_, value) => lastValue = value,
        ),
      ),
    ));

    await tester.tap(find.byTooltip('Remover foto').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(lastValue, ['/tmp/primeira.jpg']);
    expect(original, ['/tmp/primeira.jpg', '/tmp/segunda.jpg']);
    expect(find.byTooltip('Remover foto'), findsOneWidget);

    final previousValue = lastValue;
    await tester.tap(find.byTooltip('Remover foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(lastValue, isEmpty);
    expect(previousValue, ['/tmp/primeira.jpg']);
  });

  testWidgets('photo with text uses the same accessible removal control',
      (tester) async {
    dynamic lastValue = 'unchanged';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFieldWidget(
            field: BrandField(
              id: 1,
              brandId: 1,
              fieldType: 'photo_text',
              fieldLabel: 'Foto com observacao',
              fieldName: 'foto',
              displayOrder: 0,
            ),
            initialValue: const {'photo': '/uploads/photo.jpg', 'text': ''},
            onValueChanged: (_, value) => lastValue = value,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final remove = find.byTooltip('Remover foto');
    expect(tester.getSize(remove), const Size(48, 48));
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(lastValue, isNull);
    expect(find.byTooltip('Remover foto'), findsNothing);
  });

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
