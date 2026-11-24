# app_asistencia

App Flutter del empleado: autentica contra el servidor y envía la asistencia a
la tablet cuya dirección recibe del QR.

## URL del servidor de pruebas

La constante `API_BASE_URL` de `lib/api_config.dart` se recibe con
`--dart-define` al ejecutar o compilar. El login agrega `/users/authentication`.
El valor debe incluir esquema (`http://` o `https://`), host, puerto si aplica
y la ruta hasta `/api`; no incluyas `/users/authentication`, parámetros ni fragmentos.
Se acepta una barra final.

Con la dirección que tenía este proyecto, el valor es:

```text
http://192.168.1.52/horaexactaapp/web/api
```

Así, el login hace POST a
`http://192.168.1.52/horaexactaapp/web/api/users/authentication`.
Este mismo valor se conserva como predeterminado si omites `--dart-define`.

Para otro servidor sustituye `192.168.1.52` por la IP LAN o dominio del equipo
que aloja el backend. Si sirve en otro puerto, inclúyelo después del host,
por ejemplo `http://192.168.1.80:8081/horaexactaapp/web/api`.
La IP debe ser accesible desde el teléfono: `localhost` y `127.0.0.1` apuntan
al propio teléfono. Conserva o ajusta la ruta según dónde esté desplegado el backend.

## Ejecutar y compilar para Android

Desde la raíz del proyecto, con Flutter y el SDK de Android instalados:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://192.168.1.52/horaexactaapp/web/api
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.52/horaexactaapp/web/api
```

El APK se genera en `build/app/outputs/flutter-apk/app-release.apk`.
La URL queda incorporada al compilar: para cambiarla, vuelve a compilar e instala
el nuevo APK; no necesitas editar Dart. El release usa actualmente la firma de
depuración configurada en el proyecto y está destinado aquí a pruebas.

## Dirección de la tablet

`lib/scanner_view.dart` mantiene el destino `http://<ip>:<puerto>/registrar`:
`ip` y `puerto` se leen del QR (puerto predeterminado: `8080`).
`API_BASE_URL` solo configura la autenticación y no sustituye estos datos.
El teléfono debe poder alcanzar la tablet en la red local. Configura también
el generador de QR para enviar sus registros al mismo entorno de backend;
este parámetro de la app del empleado no cambia la configuración del generador.

El manifiesto principal de Android declara `INTERNET` y permite HTTP para el
servidor local y las IP variables de las tablets, también en release.
La preparación y los comandos de esta guía corresponden a Android.

Para probar en dispositivos: inicia sesión con un empleado de pruebas, escanea
un QR vigente y comprueba la recepción en la tablet y el backend de pruebas.

Referencia: [declaraciones de compilación de Dart y Flutter](https://dart.dev/libraries/core/environment-declarations).
