import 'dart:async';

import 'package:ag_merchandising/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _UploadClient extends http.BaseClient {
  _UploadClient(this.response);
  final Future<http.StreamedResponse> Function(http.BaseRequest) response;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      response(request);

  @override
  void close() => closed = true;
}

void main() {
  Future<http.MultipartRequest> request() async {
    final request = http.MultipartRequest(
        'POST', Uri.parse('https://example.invalid/api/upload/photo'));
    request.headers['X-Photo-Capture-Id'] = 'a' * 32;
    request.files.add(http.MultipartFile.fromString('photo', 'photo bytes'));
    return request;
  }

  testWidgets('photo upload can finish after the old 25 second deadline',
      (tester) async {
    final response = Completer<http.StreamedResponse>();
    final client = _UploadClient((_) => response.future);
    var completed = false;
    final upload =
        ApiService.sendMultipartWithRetry(request, clientFactory: () => client);
    upload.then((_) => completed = true);
    await tester.pump(const Duration(seconds: 26));
    expect(completed, isFalse);
    expect(client.closed, isFalse);
    response.complete(http.StreamedResponse(Stream.value([123, 125]), 200));
    await tester.pump();
    expect((await upload).statusCode, 200);
    expect(client.closed, isTrue);
  });

  testWidgets(
      '90 second timeout closes the upload without starting a duplicate',
      (tester) async {
    var attempts = 0;
    final client = _UploadClient((_) {
      attempts++;
      return Completer<http.StreamedResponse>().future;
    });
    final upload =
        ApiService.sendMultipartWithRetry(request, clientFactory: () => client);
    final result = expectLater(upload, throwsA(isA<TimeoutException>()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 89));
    expect(client.closed, isFalse);
    await tester.pump(const Duration(seconds: 1));
    await result;
    expect(client.closed, isTrue);
    expect(attempts, 1);
  });

  testWidgets('server retry rebuilds the request with the same capture ID',
      (tester) async {
    final clients = <_UploadClient>[];
    final requests = <http.BaseRequest>[];
    final upload =
        ApiService.sendMultipartWithRetry(request, clientFactory: () {
      final client = _UploadClient((request) async {
        requests.add(request);
        return http.StreamedResponse(
            const Stream.empty(), requests.length == 1 ? 503 : 200);
      });
      clients.add(client);
      return client;
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect((await upload).statusCode, 200);
    expect(requests, hasLength(2));
    expect(identical(requests[0], requests[1]), isFalse);
    expect(requests.map((request) => request.headers['X-Photo-Capture-Id']),
        everyElement('a' * 32));
    expect(clients.every((client) => client.closed), isTrue);
  });
}
