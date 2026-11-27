import 'package:app_asistencia/scanner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('El resultado mantiene la cámara apagada hasta abrir el escáner', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final messenger = tester.binding.defaultBinaryMessenger;
    const scannerChannel = MethodChannel(
      'dev.steenbakker.mobile_scanner/scanner/method',
    );
    var inicios = 0;
    var camaraActiva = false;
    var solicitudesDeSalida = 0;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') solicitudesDeSalida++;
      return null;
    });
    messenger.setMockMethodCallHandler(scannerChannel, (call) async {
      switch (call.method) {
        case 'state':
          return 1;
        case 'start':
          inicios++;
          camaraActiva = true;
          return {
            'textureId': 1,
            'cameraDirection': 1,
            'handlesCropAndRotation': true,
            'naturalDeviceOrientation': 'PORTRAIT_UP',
            'sensorOrientation': 90,
            'size': {'width': 640.0, 'height': 480.0},
          };
        case 'stop':
          camaraActiva = false;
          return null;
      }
      return null;
    });
    for (final evento in ['event', 'deviceOrientation']) {
      messenger.setMockMethodCallHandler(
        MethodChannel('dev.steenbakker.mobile_scanner/scanner/$evento'),
        (_) async => null,
      );
    }

    // Sin muestra del reloj, se prueba también el cierre en esa ruta de error.
    messenger.setMockMethodCallHandler(
      const MethodChannel('app_asistencia/clock'),
      (_) async => null,
    );
    await tester.pumpWidget(const MaterialApp(home: ScannerScreen()));
    await tester.pumpAndSettle();
    expect(inicios, 1);
    expect(camaraActiva, isTrue);

    Future<void> confirmarResultado() async {
      final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      scanner.onDetect!(
        const BarcodeCapture(barcodes: [Barcode(rawValue: 'qr de prueba')]),
      );
      await tester.pumpAndSettle();
      expect(find.text('No se pudo verificar la hora'), findsOneWidget);
      expect(camaraActiva, isFalse);
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(find.byType(MobileScanner), findsNothing);
      expect(find.text('Salir'), findsOneWidget);
      expect(find.text('Escanear nuevamente'), findsOneWidget);
    }

    await confirmarResultado();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(inicios, 1);
    expect(camaraActiva, isFalse);

    await tester.tap(find.text('Escanear nuevamente'));
    await tester.pumpAndSettle();
    expect(inicios, 2);
    expect(camaraActiva, isTrue);

    await confirmarResultado();
    expect(solicitudesDeSalida, 0);
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(solicitudesDeSalida, 1);
    expect(camaraActiva, isFalse);
    expect(inicios, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(camaraActiva, isFalse);
  });
}
