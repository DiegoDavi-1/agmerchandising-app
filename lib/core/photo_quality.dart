import 'dart:io';
import 'dart:math' as math;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'photo_standard.dart';

/// Checagem de qualidade logo apos a foto. Mesmas regras do PWA, da pagina por link,
/// do servidor (utils/photo_quality.js). Todos os avisos deixam o promotor
/// "usar mesmo assim", inclusive na primeira tentativa.
class PhotoQuality {
  PhotoQuality._();

  static const int analysisSide = 1024;
  static const double minSharpness = 75;
  static const double maxEdgeRatio = 1.08;
  static const double maxEdgeRatioCoarse = 1.25;
  static const double minBrightness = 55;
  static const double maxDarkRatio = 0.45;
  static const double maxBrightness = 220;
  static const double maxGlareRatio = 0.08;
  static const int minShortSide = 600;

  static const Map<String, List<String>> issueText = {
    'blur': [
      'Foto tremida ou desfocada',
      'Segure o celular com as duas mãos, toque na tela para focar e espere 1 segundo antes de bater.'
    ],
    'dark': [
      'Foto escura',
      'Procure mais luz ou chegue mais perto. Evite o flash em embalagens plásticas.'
    ],
    'overexposed': [
      'Foto estourada ou com reflexo',
      'Mude o ângulo para fugir do reflexo da luz/vidro e não use flash.'
    ],
    'low_resolution': [
      'Foto com pouca resolução',
      'Use a câmera traseira, sem zoom digital, e não envie print de tela.'
    ],
  };

  static String tipFor(String label) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    var text = label.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      text = text.replaceAll(from[i], to[i]);
    }
    if (RegExp(r'preco|etiqueta|oferta|tabloide|cartaz').hasMatch(text)) {
      return 'Chegue perto até a etiqueta ficar legível na tela. Não use zoom.';
    }
    if (RegExp(r'ruptura|falta|vazi').hasMatch(text)) {
      return 'Mostre o espaço vazio na prateleira junto com a etiqueta do produto.';
    }
    if (RegExp(r'validade|lote|vencimento').hasMatch(text)) {
      return 'Bem de perto, com boa luz, até a data ficar legível.';
    }
    if (RegExp(r'gondola|exposic|antes|depois|ponta|ilha|prateleira|planograma|display|check ?stand')
        .hasMatch(text)) {
      return 'Fique de frente para a gôndola e pegue ela inteira. Sem zoom e sem flash em plástico.';
    }
    return 'De frente, com o celular parado e boa luz. Sem zoom.';
  }

  /// Media de blocos factor x factor (mesmo calculo do servidor).
  static ({Float64List gray, int width, int height}) blockAverage(
      Float64List gray, int width, int height, int factor) {
    final w = width ~/ factor;
    final h = height ~/ factor;
    final out = Float64List(math.max(0, w * h));
    final area = factor * factor;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var s = 0.0;
        for (var dy = 0; dy < factor; dy++) {
          final row = (y * factor + dy) * width + x * factor;
          for (var dx = 0; dx < factor; dx++) {
            s += gray[row + dx];
          }
        }
        out[y * w + x] = s / area;
      }
    }
    return (gray: out, width: w, height: h);
  }

  /// Quanto as bordas fortes perdem ao borrar mais um pouco: foto nitida perde muito
  /// (razao baixa), foto tremida quase nada (razao perto de 1). Igual a edgeBlurRatio do servidor.
  static double edgeBlurRatio(Float64List gray, int width, int height) {
    var worst = 0.0;
    for (final horizontal in [true, false]) {
      final lines = horizontal ? height : width;
      final len = horizontal ? width : height;
      if (len < 6 || lines < 1) continue;
      double at(int l, int i) => horizontal ? gray[l * width + i] : gray[i * width + l];
      final count = lines * (len - 1);
      final d0 = Float64List(count);
      final d1 = Float64List(count);
      final blurred = Float64List(len);
      var k = 0;
      for (var l = 0; l < lines; l++) {
        for (var i = 0; i < len; i++) {
          var s = 0.0;
          for (var j = i - 2; j <= i + 2; j++) {
            s += at(l, j < 0 ? 0 : (j >= len ? len - 1 : j));
          }
          blurred[i] = s / 5;
        }
        for (var i = 0; i < len - 1; i++, k++) {
          d0[k] = (at(l, i + 1) - at(l, i)).abs();
          d1[k] = (blurred[i + 1] - blurred[i]).abs();
        }
      }
      final sorted = Float64List.fromList(d1)..sort();
      final threshold = math.max(sorted[(0.9 * (count - 1)).floor()], 3.0);
      final ratios = <double>[];
      for (var i = 0; i < count; i++) {
        if (d1[i] >= threshold) ratios.add(d0[i] / d1[i]);
      }
      if (ratios.length < 100) continue;
      ratios.sort();
      worst = math.max(worst, ratios[(ratios.length - 1) ~/ 2]);
    }
    return worst;
  }

  /// Regras a partir da imagem cinza ja reduzida para [analysisSide].
  /// [width]/[height] sao da foto original.
  static List<String> issuesForGray(Float64List gray, int w, int h, int width, int height) {
    var sum = 0.0;
    var dark = 0;
    var glare = 0;
    for (final v in gray) {
      sum += v;
      if (v <= 20) dark++;
      if (v >= 250) glare++;
    }
    var lapSum = 0.0;
    var lapSq = 0.0;
    var n = 0;
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final lap = gray[i - 1] + gray[i + 1] + gray[i - w] + gray[i + w] - 4 * gray[i];
        lapSum += lap;
        lapSq += lap * lap;
        n++;
      }
    }
    final mean = n > 0 ? lapSum / n : 0.0;
    final sharpness = n > 0 ? lapSq / n - mean * mean : 0.0;
    final half = blockAverage(gray, w, h, 2);
    final quarter = blockAverage(gray, w, h, 4);
    final edgeRatio = edgeBlurRatio(half.gray, half.width, half.height);
    final edgeRatioCoarse = edgeBlurRatio(quarter.gray, quarter.width, quarter.height);
    final total = gray.length;
    final brightness = total > 0 ? sum / total : 0.0;
    final issues = <String>[];
    if (sharpness < minSharpness ||
        edgeRatio >= maxEdgeRatio ||
        edgeRatioCoarse >= maxEdgeRatioCoarse) {
      issues.add('blur');
    }
    if (brightness < minBrightness || dark / total > maxDarkRatio) issues.add('dark');
    if (brightness > maxBrightness || glare / total > maxGlareRatio) issues.add('overexposed');
    if (math.min(width, height) < minShortSide) issues.add('low_resolution');
    return issues;
  }

  /// Roda fora da thread de interface (compute). Sem bakeOrientation: todas as
  /// medidas valem igual com a foto girada, e evita uma segunda copia da foto na memoria.
  static List<String> _measure(String path) {
    var decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) return const [];
    final width = decoded.width;
    final height = decoded.height;
    final scale = math.min(1.0, analysisSide / math.max(width, height));
    final small = scale < 1
        ? img.copyResize(decoded,
            width: math.max(3, (width * scale).round()),
            height: math.max(3, (height * scale).round()),
            interpolation: img.Interpolation.average)
        : decoded;
    decoded = null;
    final w = small.width;
    final h = small.height;
    final gray = Float64List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = small.getPixel(x, y);
        gray[y * w + x] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).roundToDouble();
      }
    }
    return issuesForGray(gray, w, h, width, height);
  }

  static Future<List<String>> measure(String path) async {
    try {
      return await compute(_measure, path);
    } catch (_) {
      return const [];
    }
  }

  /// Abre a câmera, confere a foto e repete se o promotor escolher "Tirar de novo".
  /// Retorna null se ele cancelar a câmera. Se ele usar uma foto com aviso,
  /// o nome do arquivo ganha "qa-ignored-(problemas)-" (o servidor registra isso).
  /// Todos os avisos permitem "Usar mesmo assim" desde a primeira tentativa.
  static Future<File?> captureChecked(
      BuildContext context, ImagePicker picker, String label) async {
    while (true) {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: PhotoStandard.fieldMaxSide,
        maxHeight: PhotoStandard.fieldMaxSide,
        imageQuality: PhotoStandard.fieldQuality,
        requestFullMetadata: false,
      );
      if (photo == null) return null;
      final file = File(photo.path);
      final issues = await measure(photo.path);
      if (issues.isEmpty || !context.mounted) return file;
      final useAnyway = await _ask(context, file, issues, label);
      if (useAnyway == true) {
        final dir = file.parent.path;
        final name = file.uri.pathSegments.last;
        return file.rename('$dir${Platform.pathSeparator}qa-ignored-${issues.join('-')}-$name');
      }
      try {
        await file.delete();
      } catch (_) {}
      if (!context.mounted) return null;
    }
  }

  static Future<bool?> _ask(
      BuildContext context, File file, List<String> issues, String label) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: const Color(0xFF0F172A),
                  height: MediaQuery.of(ctx).size.height * 0.34,
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 12),
              Text('Essa foto pode não servir',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
              const SizedBox(height: 8),
              ...issues.map((issue) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                          left: BorderSide(color: Color(0xFFF59E0B), width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(issueText[issue]![0],
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(issueText[issue]![1], style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )),
              Text('📸 Dica: ${tipFor(label)}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(false),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tirar de novo'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Usar mesmo assim'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Map<String, String>? _deviceHeaders;

  static Future<Map<String, String>> deviceHeaders() async {
    if (_deviceHeaders != null) return _deviceHeaders!;
    final headers = <String, String>{'X-Client': 'app'};
    String clean(String v) {
      final s = v.replaceAll(RegExp(r'[^\w .,;:()/+-]'), '').trim();
      return s.length > 100 ? s.substring(0, 100) : s;
    }
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final model = a.model.toLowerCase().startsWith(a.manufacturer.toLowerCase())
            ? a.model
            : '${a.manufacturer} ${a.model}';
        headers['X-Device-Model'] = clean(model);
        headers['X-Device-OS'] = clean('Android ${a.version.release}');
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        headers['X-Device-Model'] = clean(i.utsname.machine);
        headers['X-Device-OS'] = clean('iOS ${i.systemVersion}');
      }
    } catch (_) {}
    return _deviceHeaders = headers;
  }
}
