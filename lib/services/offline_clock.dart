import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// References are estimates from an unmodified app, not hardware attestation.
class OfflineClock {
  OfflineClock._();

  static const _key = 'offline_clock_reference_v1';
  static const _channel = MethodChannel('com.merchhub/offline_clock');
  static const maxAgeMs = 24 * 60 * 60 * 1000;
  static const maxUncertaintyMs = 10000;
  static Future<void>? _syncing;

  @visibleForTesting
  static http.Client Function() clientFactory = http.Client.new;

  static Map<String, dynamic>? _reference(String? raw) {
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic> &&
          value['owner'] is int &&
          value['boot_id'] is String &&
          value['elapsed_ms'] is int &&
          value['uncertainty_ms'] is int &&
          value['reference'] is String) {
        return value;
      }
      debugPrint(
          'Referencia offline armazenada incompleta; horario nao verificado.');
    } on FormatException catch (error) {
      debugPrint('Referencia offline armazenada invalida: $error');
    }
    return null;
  }

  static int? userId(String? token) {
    if (token == null) return null;
    try {
      final payload = jsonDecode(utf8
          .decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))));
      return payload is Map ? int.tryParse('${payload['id']}') : null;
    } on FormatException catch (error) {
      debugPrint('Referencia offline: sessao invalida: $error');
      return null;
    } on RangeError catch (error) {
      debugPrint('Referencia offline: sessao incompleta: $error');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _sample() async {
    try {
      final sample = await _channel.invokeMapMethod<String, dynamic>('sample');
      if (sample == null ||
          sample['boot_id'] is! String ||
          sample['elapsed_ms'] is! int ||
          sample['device_ms'] is! int) {
        throw const FormatException('Relogio monotonico indisponivel.');
      }
      return sample;
    } on MissingPluginException {
      debugPrint('Relogio offline nao suportado nesta plataforma.');
      return null;
    } on PlatformException catch (error) {
      debugPrint('Falha ao consultar relogio offline: $error');
      return null;
    } on FormatException catch (error) {
      debugPrint('Relogio offline invalido: $error');
      return null;
    }
  }

  static Future<void> synchronize(String baseUrl, String? token) {
    if (userId(token) == null) return Future.value();
    return _syncing ??=
        _synchronize(baseUrl, token!).whenComplete(() => _syncing = null);
  }

  static Future<void> _synchronize(String baseUrl, String token) async {
    final before = await _sample();
    if (before == null) return;
    final prefs = await SharedPreferences.getInstance();
    final previous = _reference(prefs.getString(_key));
    if (previous != null) {
      final age =
          (before['elapsed_ms'] as int) - (previous['elapsed_ms'] as int);
      if (previous['owner'] == userId(token) &&
          previous['boot_id'] == before['boot_id'] &&
          age >= 0 &&
          age < const Duration(hours: 1).inMilliseconds) {
        return;
      }
    }
    final client = clientFactory();
    try {
      final response = await client
          .post(Uri.parse('$baseUrl/time-reference'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'boot_id': before['boot_id']}))
          .timeout(const Duration(seconds: 5));
      final after = await _sample();
      if (response.statusCode != 200) {
        throw StateError(
            'Servidor recusou a referencia: ${response.statusCode}.');
      }
      final body = jsonDecode(response.body);
      final elapsed = after == null
          ? -1
          : (after['elapsed_ms'] as int) - (before['elapsed_ms'] as int);
      if (after == null ||
          before['boot_id'] != after['boot_id'] ||
          elapsed < 0 ||
          elapsed > maxUncertaintyMs ||
          body is! Map ||
          body['token'] is! String ||
          body['server_ms'] is! int) {
        throw const FormatException(
            'Referencia de horario sem precisao suficiente.');
      }
      final saved = await prefs.setString(
          _key,
          jsonEncode({
            'owner': userId(token),
            'boot_id': after['boot_id'],
            'elapsed_ms': after['elapsed_ms'],
            'server_ms': body['server_ms'],
            'uncertainty_ms': elapsed,
            'reference': body['token'],
          }));
      if (!saved) {
        throw StateError('Nao foi possivel salvar a referencia offline.');
      }
    } catch (error, stack) {
      // Offline operation continues, explicitly labelled when no valid anchor exists.
      debugPrint('Referencia de horario nao atualizada: $error\n$stack');
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> capture(String? token) async {
    final sample = await _sample();
    final result = <String, dynamic>{
      'version': 1,
      'source': 'unverified',
      'device_ms':
          sample?['device_ms'] ?? DateTime.now().millisecondsSinceEpoch,
      'reason': 'no_reference',
    };
    if (sample == null) {
      result['reason'] = 'unsupported_clock';
      return result;
    }
    final prefs = await SharedPreferences.getInstance();
    final reference = _reference(prefs.getString(_key));
    if (reference == null) return result;
    if (userId(token) == null || reference['owner'] != userId(token)) {
      result['reason'] = 'different_user';
      return result;
    }
    if (reference['boot_id'] != sample['boot_id']) {
      result['reason'] = 'device_restarted';
      return result;
    }
    final delta =
        (sample['elapsed_ms'] as int) - (reference['elapsed_ms'] as int);
    if (delta < 0 || delta > maxAgeMs) {
      result['reason'] = 'expired_reference';
      return result;
    }
    return {
      ...result,
      'source': 'server_reference',
      'reason': null,
      'reference': reference['reference'],
      'boot_id': sample['boot_id'],
      'delta_ms': delta,
      'uncertainty_ms': reference['uncertainty_ms'],
    };
  }
}
