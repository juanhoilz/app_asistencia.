import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import 'attendance_service.dart';

class AttendanceQueue {
  AttendanceQueue(this.service, this.db);
  final AttendanceService service;
  final Database db;
  static Future<Database> open() async => openDatabase(
    '${await getDatabasesPath()}/attendance_queue.db',
    version: 1,
    onCreate: (db, _) => db.execute('''CREATE TABLE attendance (
      id INTEGER PRIMARY KEY, api TEXT NOT NULL, email TEXT NOT NULL,
      employee TEXT NOT NULL, device TEXT NOT NULL, serviceKey TEXT NOT NULL,
      datetime TEXT NOT NULL, error TEXT,
      UNIQUE(api,email,employee,device,datetime))'''),
  );

  Future<List<String>> owner() async {
    final saved = await service.session.restore();
    if (saved == null) throw const SessionExpiredException();
    return [
      saved['api'] as String,
      saved['email'] as String? ?? '',
      saved['numero_empleado'] as String,
    ];
  }

  static const filter = 'api=? AND email=? AND employee=?';
  Future<int> enqueue(
    List<String> who,
    AttendanceQr qr,
    DateTime office,
  ) async {
    final time = attendanceDateTime(office);
    return db.transaction((txn) async {
      await txn.insert('attendance', {
        'api': who[0],
        'email': who[1],
        'employee': who[2],
        'device': qr.deviceId,
        'serviceKey': qr.serviceKey,
        'datetime': time,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final rows = await txn.query(
        'attendance',
        columns: ['id'],
        where: '$filter AND device=? AND datetime=?',
        whereArgs: [...who, qr.deviceId, time],
      );
      return rows.single['id'] as int;
    });
  }

  Future<List<Map<String, Object?>>> rows(List<String> who) =>
      db.query('attendance', where: filter, whereArgs: who, orderBy: 'id');

  // Un único envío activo aunque coincidan el temporizador y un escaneo.
  static Future<void> _tail = Future<void>.value();
  Future<void> flush(List<String> who, {DateTime? now}) {
    final next = _tail.then((_) => _sendPending(who, now));
    _tail = next.catchError((Object _) {});
    return next;
  }

  Future<void> _sendPending(List<String> who, DateTime? now) async {
    final pending = (await rows(who)).where((r) => r['error'] == null);
    if (pending.isEmpty) return;
    final active = await owner();
    if (active[0] != who[0] || active[1] != who[1] || active[2] != who[2]) {
      return;
    }
    try {
      // Al recuperar pendientes sin hora UTC actual, validar mediante refresh.
      final employee = await service.session.employeeForAttendance(now);
      if (employee != who[2]) {
        throw const ApiException(
          'Cambió el número de empleado. Las checadas previas se conservan con el número original.',
        );
      }
      for (final row in pending) {
        try {
          await service.send(
            AttendanceQr(row['device'] as String, row['serviceKey'] as String),
            row['datetime'] as String,
            employee,
          );
        } on ApiException catch (e) {
          final code = e.status;
          if (code == null || code >= 500 || code == 408 || code == 429) return;
          await db.update(
            'attendance',
            {'error': e.message},
            where: 'id=?',
            whereArgs: [row['id']],
          );
          continue;
        }
        await db.delete('attendance', where: 'id=?', whereArgs: [row['id']]);
      }
    } on ApiException catch (e) {
      if (e.status != null &&
          (e.status! >= 500 || e.status == 408 || e.status == 429)) {
        return;
      }
      rethrow;
    } on TimeoutException {
      return;
    } on http.ClientException {
      return;
    }
  }
}
