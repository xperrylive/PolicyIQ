// api_client.dart — PolicyIQ HTTP + SSE Client
//
// Provides:
//   - [validatePolicy]  POST /validate-policy  (Contract Pre-A → Pre-B)
//   - [simulateStream]  POST /simulate          (Contract A → SSE tick/complete events)

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/contracts.dart';

// ─── Configuration ────────────────────────────────────────────────────────────

const String _kApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000');

// ─── ApiClient ────────────────────────────────────────────────────────────────

class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;

  ApiClient({String? baseUrl, http.Client? httpClient})
      : baseUrl = baseUrl ?? _kApiBaseUrl,
        _httpClient = httpClient ?? http.Client();

  // ── Contract Pre-A → Pre-B ─────────────────────────────────────────────────

  Future<ValidatePolicyResponse> validatePolicy(String rawPolicyText) async {
    final uri = Uri.parse('$baseUrl/validate-policy');
    final request = ValidatePolicyRequest(rawPolicyText: rawPolicyText);

    final response = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      return ValidatePolicyResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw ApiException(response.statusCode, response.body);
  }

  // ── Contract A → SSE (tick / complete / error events) ─────────────────────

  Stream<SseEvent> simulateStream(SimulateRequest request) async* {
    final uri = Uri.parse('$baseUrl/simulate');

    final httpRequest = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode(request.toJson());

    late http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _httpClient.send(httpRequest);
    } catch (e) {
      throw ApiException(0, 'Network error: $e');
    }

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw ApiException(streamedResponse.statusCode, body);
    }

    String eventType = 'message';
    final StringBuffer dataBuffer = StringBuffer();

    await for (final chunk
        in streamedResponse.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.startsWith('event:')) {
          eventType = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          dataBuffer.write(line.substring(5).trim());
        } else if (line.isEmpty && dataBuffer.isNotEmpty) {
          final rawData = dataBuffer.toString();
          dataBuffer.clear();

          Map<String, dynamic> payload;
          try {
            payload = jsonDecode(rawData) as Map<String, dynamic>;
          } catch (_) {
            payload = {'raw': rawData};
          }

          yield SseEvent(type: eventType, data: payload);

          if (eventType == 'complete' || eventType == 'error') return;
          eventType = 'message';
        }
      }
    }
  }

  Future<String> exportReport(String simulationId) async {
    final uri = Uri.parse('$baseUrl/export-report/$simulationId');
    final response = await _httpClient.get(uri);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['report'] as String? ?? response.body;
    }
    throw ApiException(response.statusCode, response.body);
  }

  void dispose() => _httpClient.close();
}

// ─── SSE Event ────────────────────────────────────────────────────────────────

class SseEvent {
  final String type;
  final Map<String, dynamic> data;

  const SseEvent({required this.type, required this.data});

  @override
  String toString() => 'SseEvent(type: $type, data: $data)';
}

// ─── ApiException ─────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
