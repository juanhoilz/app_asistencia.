# app_asistencia

App Flutter del empleado: autentica contra el servidor y envía la asistencia
directamente al backend con el contrato Java existente.

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

## Registro directo mediante QR

El QR debe ser un objeto JSON con `deviceId` y `serviceKey`, ambos textos no
vacíos. Ya no se utilizan `ip`, `puerto` ni `ts`. Los QR anteriores no son compatibles.

El registro hace POST a `API_BASE_URL/asistencias/registrar`, sin Bearer,
enviando exclusivamente `deviceId`, `serviceKey`, `datetime` y `employeeNumber`.
El dispositivo debe existir como Java y la clave debe corresponder a su servicio.
El backend no se modifica; este contrato no vincula el empleado enviado con un JWT.

`datetime` representa el instante del escaneo en `America/Mexico_City`, con el
formato `yyyy/MM/dd HH:mm:ss`. En Android se calcula con una referencia HTTPS
y el contador de tiempo transcurrido desde el arranque. Al primer escaneo tras
las 04:00 de la oficina o después de reiniciar el teléfono, se intenta renovar
la referencia con TimeAPI.io y luego con timezone.io si falla el primero.
Sin referencia vigente, se puede abrir la app e iniciar sesión, pero el escáner
impide el envío y permite volver a intentar. La hora calculada también se usa
para decidir si hay que renovar el token antes de enviar.
`employeeNumber` procede de `numero_empleado` del login. Se guardan también
`access_token`, `refresh_token` y `expires_at`. Al vencer la sesión (con margen de
30 segundos), se llama a `/users/authentication/refresh-token` y se actualiza el
número de empleado con su respuesta antes de registrar. Una renovación rechazada
por autenticación devuelve al login; un fallo de red impide enviar la asistencia.
Las sesiones antiguas sin tokens requieren iniciar sesión nuevamente.

La app restaura la sesión desde almacenamiento seguro al abrirse. Después de
un escaneo con hora válida, guarda la checada en SQLite antes de enviarla.
Si falla la conexión, conserva el registro y su hora original. Con el escáner
abierto intenta sincronizar cada 20 segundos y al regresar a la pantalla.
Solo procesa la cola del servidor, cuenta y empleado activos. Un rechazo
definitivo del registro se conserva como rechazado y no se reintenta.
El teléfono debe poder alcanzar el backend; una IP LAN requiere acceso a esa red.

El manifiesto principal de Android declara `INTERNET` y permite HTTP para el
servidor local, también en release.
La preparación y los comandos de esta guía corresponden a Android.

Para probar en dispositivos: inicia sesión con un empleado de pruebas, escanea
un QR de un dispositivo Java y comprueba la recepción en el backend de pruebas.

Referencia: [declaraciones de compilación de Dart y Flutter](https://dart.dev/libraries/core/environment-declarations).
