import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'offline_clock.dart';
import '../core/network/connectivity_service.dart';

class PhotoCaptureTime {
  PhotoCaptureTime._();

  static final Map<String, Future<void>> _sealing = {};
  @visibleForTesting
  static http.Client Function() clientFactory = http.Client.new;
  @visibleForTesting
  static Future<bool> Function() isOnline =
      () => ConnectivityService().isOnline();

  static File proofFile(File photo) => File('${photo.path}.timeproof');

  static Future<Map<String, dynamic>> _post(
      String endpoint, Map<String, String> body) async {
    final client = clientFactory();
    Future<http.Response> send() => client
        .post(Uri.parse('${ApiService.baseUrl}/photo-time/$endpoint'),
            headers: ApiService.getHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 5));
    try {
      var response = await send();
      if (response.statusCode == 401) {
        await ApiService.checkTokenExpired(401);
        response = await send();
      }
      final result = jsonDecode(response.body);
      if (result is! Map<String, dynamic> ||
          response.statusCode != 200 ||
          result['success'] != true) {
        throw StateError(result is Map
            ? '${result['error'] ?? 'Não foi possível registrar o horário da foto.'}'
            : 'Resposta inválida ao registrar o horário da foto.');
      }
      return result;
    } on SocketException {
      throw StateError(
          'Conecte-se à internet para registrar o horário da foto.');
    } on TimeoutException {
      throw StateError(
          'O servidor não respondeu. Conecte-se e tente novamente.');
    } on http.ClientException {
      throw StateError(
          'Conecte-se à internet para registrar o horário da foto.');
    } finally {
      client.close();
    }
  }

  static Future<String> start() async {
    final start = await OfflineClock.capture(ApiService.token);
    String? onlineToken;
    if (await isOnline()) {
      try {
        onlineToken = (await _post('start', {}))['token'] as String?;
      } catch (error, stack) {
        debugPrint(
            'Captura sem intervalo online; usando evidencia local: $error\n$stack');
      }
    }
    return jsonEncode({
      'version': 1,
      'start': start,
      'server_token': onlineToken,
    });
  }

  static Future<void> seal(File photo, String token, {bool recovered = false}) {
    return _sealing.putIfAbsent(photo.path, () {
      return _seal(photo, token, recovered: recovered).whenComplete(() {
        _sealing.remove(photo.path);
      });
    });
  }

  static Future<void> _seal(File photo, String token,
      {required bool recovered}) async {
    final digest = await sha256.bind(photo.openRead()).first;
    String proof;
    if (token.startsWith('{')) {
      final saved = jsonDecode(token) as Map<String, dynamic>;
      proof = jsonEncode({
        'version': 1,
        'digest': '$digest',
        'start': saved['start'],
        'end': recovered
            ? {'source': 'unverified', 'reason': 'interrupted_capture'}
            : await OfflineClock.capture(ApiService.token),
      });
      final serverToken = saved['server_token'];
      if (!recovered && serverToken is String && await isOnline()) {
        try {
          final response = await _post(
              'finish', {'token': serverToken, 'sha256': '$digest'});
          final serverProof = response['proof'];
          if (serverProof is! String || serverProof.isEmpty) {
            throw const FormatException('Comprovante de horario ausente.');
          }
          proof = serverProof;
        } catch (error, stack) {
          debugPrint(
              'Intervalo online nao concluido; metadados locais preservados: $error\n$stack');
        }
      }
    } else {
      // Preserve recoverable captures made by the previous preview.
      final result =
          await _post('finish', {'token': token, 'sha256': '$digest'});
      final legacyProof = result['proof'];
      if (legacyProof is! String || legacyProof.isEmpty) {
        throw const FormatException('Comprovante de horário ausente.');
      }
      proof = legacyProof;
    }
    final target = proofFile(photo);
    final temporary = File('${target.path}.part');
    await temporary.writeAsString(proof, flush: true);
    await temporary.rename(target.path);
  }
}
