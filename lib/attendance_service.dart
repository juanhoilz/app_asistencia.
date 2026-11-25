import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, [this.status]);
  final String message;
  final int? status;
}

class SessionExpiredException extends ApiException {
  const SessionExpiredException() : super('Inicia sesión nuevamente.');
}

String apiError(http.Response response, String fallback) {
  try {
    final data = jsonDecode(response.body);
    if (data is Map && data['errorMessage'] is String) {
      return data['errorMessage'] as String;
    }
  } on FormatException {
    // Un proxy puede responder HTML en lugar de JSON.
  }
  return '$fallback (HTTP ${response.statusCode}).';
}

class UserSession {
  UserSession(this.preferences, this.client);
  final SharedPreferences preferences;
  final http.Client client;
  static const vault = FlutterSecureStorage();
  static const key = 'attendance_session_v1';

  Future<Map<String, dynamic>?> restore() async {
    final raw = await vault.read(key: key);
    if (raw != null) {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      if (saved['api'] == apiEndpoint('').toString()) return saved;
      return null;
    }
    if (preferences.getString('session_api') != apiEndpoint('').toString()) {
      return null;
    }
    final legacy = {
      for (final k in [
        'numero_empleado',
        'access_token',
        'refresh_token',
        'expires_at',
      ])
        k: preferences.get(k),
    };
    try {
      await save(legacy, email: preferences.getString('logged_email'));
    } on ApiException {
      return null;
    }
    return restore();
  }

  static String? _employee(dynamic value) {
    if (value is! String && value is! int) return null;
    final employee = value.toString().trim();
    if (employee.isEmpty ||
        employee.toLowerCase() == 'null' ||
        employee.toLowerCase() == 'admin') {
      return null;
    }
    return employee;
  }

  Future<void> save(dynamic data, {String? email}) async {
    if (data is! Map) {
      throw const ApiException('La respuesta de sesión no es válida.');
    }
    final employee = _employee(data['numero_empleado']);
    final access = data['access_token'];
    final refresh = data['refresh_token'];
    final expires = data['expires_at'];
    if (employee == null ||
        access is! String ||
        access.trim().isEmpty ||
        refresh is! String ||
        refresh.trim().isEmpty ||
        expires is! int ||
        expires <= 0) {
      throw const ApiException('La sesión recibida está incompleta.');
    }
    await vault.write(
      key: key,
      value: jsonEncode({
        'api': apiEndpoint('').toString(),
        'email': email?.trim().toLowerCase(),
        'numero_empleado': employee,
        'access_token': access,
        'refresh_token': refresh,
        'expires_at': expires,
      }),
    );
    await _clearLegacy();
  }

  Future<void> clear() async {
    await _clearLegacy();
    await vault.delete(key: key);
  }

  Future<void> _clearLegacy() async {
    for (final key in [
      'numero_empleado',
      'access_token',
      'refresh_token',
      'expires_at',
      'session_api',
      'logged_email',
    ]) {
      await preferences.remove(key);
    }
  }

  Future<String> employeeForAttendance(DateTime? trustedUtc) async {
    final saved = await restore();
    if (saved == null) {
      throw const SessionExpiredException();
    }
    if (trustedUtc == null ||
        saved['expires_at'] <= trustedUtc.millisecondsSinceEpoch ~/ 1000 + 30) {
      final response = await client
          .post(
            refreshTokenUrl,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refresh_token': saved['refresh_token']}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 || response.statusCode == 403) {
        await clear();
        throw const SessionExpiredException();
      }
      if (response.statusCode != 200) {
        throw ApiException(
          apiError(response, 'No se pudo renovar la sesión'),
          response.statusCode,
        );
      }
      final renewed = jsonDecode(response.body);
      await save(renewed, email: saved['email'] as String?);
      return _employee(renewed['numero_empleado'])!;
    }
    return saved['numero_empleado'] as String;
  }
}

class AttendanceQr {
  const AttendanceQr(this.deviceId, this.serviceKey);
  final String deviceId;
  final String serviceKey;

  factory AttendanceQr.parse(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map ||
        data['deviceId'] is! String ||
        data['serviceKey'] is! String ||
        (data['deviceId'] as String).trim().isEmpty ||
        (data['serviceKey'] as String).trim().isEmpty) {
      throw const FormatException(
        'El QR debe contener deviceId y serviceKey como texto.',
      );
    }
    return AttendanceQr(data['deviceId'].trim(), data['serviceKey'].trim());
  }
}

String attendanceDateTime(DateTime time) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${time.year.toString().padLeft(4, '0')}/${two(time.month)}/${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

class AttendanceService {
  AttendanceService(this.session, this.client);
  final UserSession session;
  final http.Client client;

  Future<String> register(
    AttendanceQr qr,
    DateTime scannedAt, {
    required DateTime trustedUtc,
  }) async {
    final employee = await session.employeeForAttendance(trustedUtc);
    await send(qr, attendanceDateTime(scannedAt), employee);
    return employee;
  }

  Future<void> send(AttendanceQr qr, String datetime, String employee) async {
    final response = await client
        .post(
          attendanceUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'datetime': datetime,
            'deviceId': qr.deviceId,
            'employeeNumber': employee,
            'serviceKey': qr.serviceKey,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        apiError(response, 'El servidor rechazó el registro'),
        response.statusCode,
      );
    }
  }
}
