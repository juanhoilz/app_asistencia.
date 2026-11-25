import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceTimeUnavailable implements Exception {
  const AttendanceTimeUnavailable();
}

typedef ClockSample = ({int boot, int elapsedMs});
typedef ScanTime = ({DateTime utc, DateTime office});
typedef _Reference = ({ClockSample sample, DateTime utc});

class AttendanceClock {
  AttendanceClock(
    this.preferences,
    this.client, {
    this.sample = deviceSample,
    this.officeOffset = _deviceOfficeOffset,
  });

  static const _channel = MethodChannel('app_asistencia/clock');
  static const _key = 'attendance_time_reference_v1';
  static const _zone = 'America/Mexico_City';
  static final primary = Uri.https('timeapi.io', '/api/Time/current/zone', {
    'timeZone': _zone,
  });
  static final backup = Uri.https(
    'worldtime.timezone.io',
    '/api/timezone/$_zone',
  );
  static const _timeout = Duration(seconds: 4);
  final SharedPreferences preferences;
  final http.Client client;
  final Future<ClockSample> Function() sample;
  final Future<int> Function(DateTime utc) officeOffset;

  static Future<ClockSample> deviceSample() async {
    try {
      final values = await _channel.invokeListMethod<int>('sample');
      if (values != null &&
          values.length == 2 &&
          values[0] >= 0 &&
          values[1] >= 0) {
        return (boot: values[0], elapsedMs: values[1]);
      }
    } on PlatformException {
      throw const AttendanceTimeUnavailable();
    } on MissingPluginException {
      throw const AttendanceTimeUnavailable();
    }
    throw const AttendanceTimeUnavailable();
  }

  static Future<int> _deviceOfficeOffset(DateTime utc) async {
    try {
      final offset = await _channel.invokeMethod<int>(
        'officeOffset',
        utc.millisecondsSinceEpoch,
      );
      if (offset != null) return offset;
    } on PlatformException {
      throw const AttendanceTimeUnavailable();
    } on MissingPluginException {
      throw const AttendanceTimeUnavailable();
    }
    throw const AttendanceTimeUnavailable();
  }

  Future<DateTime> _office(DateTime utc) async =>
      utc.add(Duration(milliseconds: await officeOffset(utc)));

  _Reference? _stored() {
    final raw = preferences.getString(_key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is List && data.length == 3 && data.every((v) => v is int)) {
        return (
          sample: (boot: data[0] as int, elapsedMs: data[1] as int),
          utc: DateTime.fromMillisecondsSinceEpoch(data[2] as int, isUtc: true),
        );
      }
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
    return null;
  }

  DateTime _at(_Reference reference, ClockSample point) => reference.utc.add(
    Duration(milliseconds: point.elapsedMs - reference.sample.elapsedMs),
  );

  int _attendanceDay(DateTime office) {
    final day = office.subtract(const Duration(hours: 4));
    return day.year * 10000 + day.month * 100 + day.day;
  }

  Future<bool> _valid(_Reference reference, ClockSample now) async {
    final age = now.elapsedMs - reference.sample.elapsedMs;
    if (reference.sample.boot != now.boot ||
        age < 0 ||
        age >= const Duration(hours: 25).inMilliseconds) {
      return false;
    }
    return _attendanceDay(await _office(reference.utc)) ==
        _attendanceDay(await _office(_at(reference, now)));
  }

  Future<ScanTime> forScan(ClockSample scan) async {
    final now = await sample();
    if (scan.boot != now.boot || scan.elapsedMs > now.elapsedMs) {
      throw const AttendanceTimeUnavailable();
    }
    var reference = _stored();
    if (reference == null || !await _valid(reference, now)) {
      reference = await _synchronize();
    }
    if (reference.sample.boot != scan.boot) {
      throw const AttendanceTimeUnavailable();
    }
    final utc = _at(reference, scan);
    return (utc: utc, office: await _office(utc));
  }

  Future<_Reference> _synchronize() async {
    for (final url in [primary, backup]) {
      try {
        final start = await sample();
        final response = await client
            .get(
              url,
              headers: {
                'Accept': 'application/json',
                'Cache-Control': 'no-cache',
              },
            )
            .timeout(_timeout);
        final end = await sample();
        final age = response.headers['age'];
        if (response.statusCode != 200 ||
            (age != null && age.trim() != '0') ||
            start.boot != end.boot ||
            end.elapsedMs < start.elapsedMs ||
            end.elapsedMs - start.elapsedMs > _timeout.inMilliseconds) {
          continue;
        }
        final utc = await _parseUtc(jsonDecode(response.body), url == primary);
        final reference = (
          sample: end,
          utc: utc.add(
            Duration(milliseconds: (end.elapsedMs - start.elapsedMs) ~/ 2),
          ),
        );
        await preferences.setString(
          _key,
          jsonEncode([
            end.boot,
            end.elapsedMs,
            reference.utc.millisecondsSinceEpoch,
          ]),
        );
        return reference;
      } on FormatException {
        continue;
      } on http.ClientException {
        continue;
      } on TimeoutException {
        continue;
      }
    }
    throw const AttendanceTimeUnavailable();
  }

  Future<DateTime> _parseUtc(Object? data, bool isPrimary) async {
    final value = data is Map
        ? data[isPrimary ? 'dateTime' : 'utc_datetime']
        : null;
    if (data is! Map ||
        data[isPrimary ? 'timeZone' : 'timezone'] != _zone ||
        value is! String) {
      throw const FormatException('Respuesta de hora inválida.');
    }
    final pattern = isPrimary
        ? r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?$'
        : r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|\+00:00)$';
    if (!RegExp(pattern).hasMatch(value)) {
      throw const FormatException('Formato de hora inválido.');
    }
    final timestamp = DateTime.parse(isPrimary ? '${value}Z' : value);
    // DateTime.parse normaliza fechas fuera de rango en vez de rechazarlas.
    if (!timestamp.toIso8601String().startsWith(value.substring(0, 19))) {
      throw const FormatException('Fecha u hora fuera de rango.');
    }
    if (!isPrimary) return timestamp;
    // TimeAPI entrega la hora civil sin offset. Interpretarla en la zona de la oficina.
    final civil = timestamp;
    final utc = civil.subtract(
      Duration(milliseconds: await officeOffset(civil)),
    );
    if (await _office(utc) != civil) {
      throw const FormatException(
        'La hora no corresponde a la zona de la oficina.',
      );
    }
    return utc;
  }
}
