import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_asistencia/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  testWidgets('Required fields and password visibility', (tester) async {
    await tester.pumpWidget(const MiAppAsistencia());
    await tester.pumpAndSettle();
    expect(find.text('Acceso Empleado'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    final password = find.byType(TextField).last;
    expect(tester.widget<TextField>(password).obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isFalse);
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(find.text('Por favor, llena todos los campos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(412, 915),
    const Size(800, 1280),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Fits $size at text scale $scale with keyboard', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(TextField).first);
        await tester.tap(find.byType(TextField).first);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Continuar'));
        await tester.pumpAndSettle();
        expect(find.text('Continuar').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
