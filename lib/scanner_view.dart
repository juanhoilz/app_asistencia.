import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'attendance_service.dart';
import 'attendance_clock.dart';
import 'attendance_queue.dart';
import 'attendance_confirmation_dialog.dart';
import 'login_style.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  String? _resultado;
  bool _estaProcesando = false;
  bool _enviando = false;
  final MobileScannerController cameraController = MobileScannerController();
  final http.Client _client = http.Client();
  late final Future<AttendanceQueue> _queue = _openQueue();
  Timer? _timer;
  bool _syncing = false;
  String _status = '';

  Future<AttendanceQueue> _openQueue() async {
    final session = UserSession(await SharedPreferences.getInstance(), _client);
    return AttendanceQueue(
      AttendanceService(session, _client),
      await AttendanceQueue.open(),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  void _resume() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _retry());
    unawaited(_retry());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      _timer?.cancel();
    }
  }

  String _summary(List<Map<String, Object?>> rows) {
    final rejected = rows.where((r) => r['error'] != null).length;
    if (rows.isEmpty) return '';
    return 'Pendientes: ${rows.length - rejected}${rejected > 0 ? ' · Rechazadas: $rejected' : ''}';
  }

  Future<void> _retry() async {
    if (!mounted || _syncing || _estaProcesando) return;
    _syncing = true;
    try {
      final queue = await _queue;
      final owner = await queue.owner();
      await queue.flush(owner);
      final status = _summary(await queue.rows(owner));
      if (mounted && !_estaProcesando && status != _status) {
        setState(() => _status = status);
      }
    } on SessionExpiredException {
      if (mounted && !_estaProcesando) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (_) {
      if (mounted && !_estaProcesando) {
        setState(() => _status = 'Sincronización pendiente');
      }
    } finally {
      _syncing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _client.close();
    unawaited(cameraController.dispose());
    super.dispose();
  }

  Future<void> _logout() async {
    if (_syncing || _estaProcesando) return;
    setState(() => _estaProcesando = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await UserSession(prefs, _client).clear();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _estaProcesando = false;
          _status = 'No se pudo cerrar la sesión';
        });
      }
    }
  }

  Future<void> _procesarQR(String raw) async {
    if (!mounted || _estaProcesando || _resultado != null) {
      return;
    }
    setState(() => _estaProcesando = true);
    bool volverAlLogin = false;
    bool? pendingConfirmation;
    String title;
    String? message;
    try {
      final ClockSample scan;
      try {
        scan = await AttendanceClock.deviceSample();
      } finally {
        await cameraController.stop();
      }
      final qr = AttendanceQr.parse(raw);
      if (!mounted) return;
      setState(() => _enviando = true);
      final prefs = await SharedPreferences.getInstance();
      final scannedAt = await AttendanceClock(prefs, _client).forScan(scan);
      if (!mounted) return;
      final queue = await _queue;
      final who = await queue.owner();
      final id = await queue.enqueue(who, qr, scannedAt.office);
      await queue.flush(who, now: scannedAt.utc);
      final rows = await queue.rows(who);
      _status = _summary(rows);
      final row = rows.where((r) => r['id'] == id).firstOrNull;
      if (row?['error'] case final String error) throw ApiException(error);
      title = row == null
          ? 'Asistencia registrada'
          : 'Checada guardada · pendiente de envío';
      pendingConfirmation = row != null;
    } on AttendanceTimeUnavailable {
      title = 'No se pudo verificar la hora';
      message = 'La checada no se envió. Comprueba tu conexión y vuelve a escanear para reintentar.';
    } on SessionExpiredException catch (e) {
      volverAlLogin = true;
      title = 'Sesión vencida';
      message = e.message;
    } on FormatException {
      title = 'Datos inválidos';
      message = 'Verifica que el QR contenga deviceId y serviceKey como texto y que el servidor responda correctamente.';
    } on ApiException catch (e) {
      title = 'No se pudo registrar';
      message = e.message;
    } on TimeoutException {
      title = 'Tiempo de espera agotado';
      message = 'No se recibió confirmación. Verifica si la asistencia se registró antes de escanear otra vez.';
    } catch (_) {
      title = 'No se pudo confirmar el registro';
      message = 'Comprueba la conexión con el servidor y verifica tu asistencia antes de volver a intentar.';
    }
    if (!mounted) return;
    setState(() => _enviando = false);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => pendingConfirmation != null
          ? AttendanceConfirmationDialog(pending: pendingConfirmation)
          : AlertDialog(
              title: Text(title),
              content: message == null ? null : Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(volverAlLogin ? 'Iniciar sesión' : 'Aceptar'),
                ),
              ],
            ),
    );
    if (!mounted) return;
    if (volverAlLogin) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }
    setState(() {
      _resultado = title;
      _estaProcesando = false;
    });
  }

  void _abrirEscaner() {
    setState(() => _resultado = null);
  }

  Widget _sinCamara(String resultado) {
    return ColoredBox(
      color: LoginColors.pearl,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            margin: EdgeInsets.zero,
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            shadowColor: LoginColors.graphite.withValues(alpha: 0.16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: AttendanceResultContent(
              title: resultado,
              icon: Icons.qr_code_scanner_rounded,
              primaryLabel: 'Escanear nuevamente',
              onPrimary: _estaProcesando ? null : _abrirEscaner,
              secondaryAction: OutlinedButton(
                onPressed: _estaProcesando ? null : SystemNavigator.pop,
                style: OutlinedButton.styleFrom(
                  foregroundColor: LoginColors.primary,
                  backgroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  side: const BorderSide(color: LoginColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Salir'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultado = _resultado;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escáner de Asistencia'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: _status.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(30),
                child: Text(_status),
              ),
      ),
      body: resultado == null ? _escaner() : _sinCamara(resultado),
    );
  }

  Widget _escaner() => Stack(
    children: [
      MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            if (barcode.rawValue != null) {
              unawaited(_procesarQR(barcode.rawValue!));
              break;
            }
          }
        },
      ),
      Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green, width: 4),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      if (_enviando)
        const Positioned.fill(
          child: ColoredBox(
            color: Colors.black54,
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Registrando asistencia…'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
