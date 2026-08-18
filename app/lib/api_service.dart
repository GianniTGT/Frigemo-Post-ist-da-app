import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class Employee {
  final String id;
  final String name;
  final String email;
  final String department;

  const Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'].toString(),
        name: (json['name'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        department: (json['department'] ?? '').toString(),
      );
}

class DeliveryDraft {
  final String carrierId;
  final String carrierLabel;
  final String employeeId;
  final int quantity;
  final String kind;
  final String location;
  final String note;

  const DeliveryDraft({
    required this.carrierId,
    required this.carrierLabel,
    required this.employeeId,
    required this.quantity,
    required this.kind,
    required this.location,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'carrierId': carrierId,
        'carrierLabel': carrierLabel,
        'employeeId': employeeId,
        'quantity': quantity,
        'kind': kind,
        'location': location,
        'note': note,
        'terminalId': AppConfig.terminalId,
      };
}

enum ApiErrorKind { network, timeout, unauthorized, server, mailFailed }

class ApiException implements Exception {
  final ApiErrorKind kind;
  final String? detail;

  const ApiException(this.kind, [this.detail]);

  /// Übersetzungsschlüssel für die Anzeige.
  String get messageKey => switch (kind) {
        ApiErrorKind.network => 'error.network',
        ApiErrorKind.timeout => 'error.timeout',
        ApiErrorKind.unauthorized => 'error.auth',
        ApiErrorKind.mailFailed => 'error.mail',
        ApiErrorKind.server => 'error.server',
      };

  @override
  String toString() => 'ApiException($kind, $detail)';
}

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'accept': 'application/json',
        if (AppConfig.apiKey.isNotEmpty) 'x-api-key': AppConfig.apiKey,
        'x-terminal-id': AppConfig.terminalId,
      };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.apiBaseUrl}$path').replace(queryParameters: query);

  Future<bool> health() async {
    try {
      final res = await _client
          .get(_uri('/health'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Suche läuft serverseitig – das Terminal hält nie die ganze Liste.
  Future<List<Employee>> searchEmployees(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < AppConfig.minSearchChars) return const [];

    final res = await _send(() => _client.get(
          _uri('/employees', {
            'q': trimmed,
            'limit': '${AppConfig.maxSearchResults}',
          }),
          headers: _headers,
        ));

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final list = decoded is Map ? decoded['data'] : decoded;
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Employee.fromJson)
        .toList(growable: false);
  }

  Future<void> submitDelivery(DeliveryDraft draft) async {
    final res = await _send(() => _client.post(
          _uri('/deliveries'),
          headers: _headers,
          body: jsonEncode(draft.toJson()),
        ));

    // Der Server nimmt die Sendung an (201), auch wenn der Mailversand
    // scheitert – das muss der Empfang aber wissen.
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['mailStatus'] == 'failed') {
        throw const ApiException(ApiErrorKind.mailFailed);
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      // Antwort ohne verwertbaren Body: Statuscode war ok, also akzeptieren.
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response res;
    try {
      res = await request().timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw const ApiException(ApiErrorKind.timeout);
    } catch (e) {
      throw ApiException(ApiErrorKind.network, e.toString());
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const ApiException(ApiErrorKind.unauthorized);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(ApiErrorKind.server, 'HTTP ${res.statusCode}');
    }
    return res;
  }

  void dispose() => _client.close();
}
