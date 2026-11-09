import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ag_merchandising/core/photo_quality.dart';

// Mesmos casos de meu-servidor/utils/photo_quality.test.js.
Float64List image(int w, int h, int Function(int x, int y) fn) {
  final g = Float64List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      g[y * w + x] = fn(x, y).toDouble();
    }
  }
  return g;
}

int checker(int x, int y) => ((x >> 4) + (y >> 4)) % 2 == 1 ? 200 : 60;

// Media horizontal de `len` pixels: simula o celular mexendo para o lado na hora da foto.
int Function(int, int) shaken(int len) => (x, y) {
      var s = 0;
      for (var i = 0; i < len; i++) {
        s += checker(x + i, y);
      }
      return (s / len).round();
    };

List<String> issues(Float64List g, int w, int h, int width, int height) =>
    PhotoQuality.issuesForGray(g, w, h, width, height);

void main() {
  test('foto nitida e bem exposta nao tem problemas', () {
    expect(issues(image(400, 300, checker), 400, 300, 2048, 1536), isEmpty);
  });

  test('foto lisa e borrada', () {
    expect(issues(image(400, 300, (x, y) => 100 + (x % 50) ~/ 10), 400, 300, 2048, 1536),
        contains('blur'));
  });

  test('foto tremida para o lado vira blur mesmo com bastante contraste', () {
    final g = image(400, 300, shaken(6));
    final half = PhotoQuality.blockAverage(g, 400, 300, 2);
    expect(PhotoQuality.edgeBlurRatio(half.gray, half.width, half.height),
        greaterThanOrEqualTo(PhotoQuality.maxEdgeRatio));
    expect(issues(g, 400, 300, 2048, 1536), contains('blur'));
  });

  test('tremido maior aparece na escala grossa e na pior direcao', () {
    final shake = shaken(12);
    final g = image(300, 400, (x, y) => shake(y, x));
    final quarter = PhotoQuality.blockAverage(g, 300, 400, 4);
    expect(PhotoQuality.edgeBlurRatio(quarter.gray, quarter.width, quarter.height),
        greaterThanOrEqualTo(PhotoQuality.maxEdgeRatioCoarse));
    expect(issues(g, 300, 400, 1536, 2048), contains('blur'));
  });

  test('foto escura', () {
    expect(issues(image(400, 300, (x, y) => checker(x, y) ~/ 8), 400, 300, 2048, 1536),
        contains('dark'));
  });

  test('foto estourada', () {
    expect(
        issues(image(400, 300, (x, y) => checker(x, y) > 100 ? 255 : 240), 400, 300, 2048, 1536),
        contains('overexposed'));
  });

  test('baixa resolucao usa o tamanho original', () {
    expect(issues(image(400, 300, checker), 400, 300, 640, 480), contains('low_resolution'));
  });
}
