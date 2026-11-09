import 'dart:io';

import 'package:ag_merchandising/core/photo_quality.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class _Picker extends ImagePicker {
  _Picker(this.file);

  final File file;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile(file.path);
}

void main() {
  testWidgets('first blurry photo can be used with quality marker', (tester) async {
    final directory = Directory.systemTemp.createTempSync('photo-review-');
    final original = File('${directory.path}${Platform.pathSeparator}photo.jpg');
    original.writeAsBytesSync(img.encodeJpg(img.Image(width: 640, height: 640)));
    addTearDown(() => directory.deleteSync(recursive: true));

    late Future<File?> captured;
    late BuildContext captureContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        captureContext = context;
        return const Scaffold();
      }),
    ));

    await tester.runAsync(() async {
      captured = PhotoQuality.captureChecked(captureContext, _Picker(original), 'Foto');
    });
    for (var attempt = 0; attempt < 50 &&
        find.text('Usar mesmo assim').evaluate().isEmpty; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Foto tremida ou desfocada'), findsOneWidget);
    expect(find.text('Usar mesmo assim'), findsOneWidget);
    expect(find.text('Tirar de novo'), findsOneWidget);
    expect(find.textContaining('Tentativa'), findsNothing);

    await tester.tap(find.text('Usar mesmo assim'));
    await tester.pumpAndSettle();
    final accepted = await tester.runAsync(() => captured);
    expect(accepted, isNotNull);
    expect(accepted!.uri.pathSegments.last, startsWith('qa-ignored-blur-dark-'));
    expect(accepted.existsSync(), isTrue);
    expect(original.existsSync(), isFalse);
  });
}
