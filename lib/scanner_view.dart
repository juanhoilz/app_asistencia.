import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _estaProcesando = false;
  MobileScannerController cameraController = MobileScannerController();

  // --- 1. PROCESAMIENTO LIMPIO DEL QR ---
  Future<void> _procesarQR(String qrData) async {
    if (_estaProcesando) return;
    setState(() => _estaProcesando = true);
    
    cameraController.stop(); // Pausamos la cámara

    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedEmail = prefs.getString('logged_email') ?? '';
      // IMPORTANTE: Asegúrate de guardar 'logged_password' en tu Pantalla de Login
      final loggedPassword = prefs.getString('logged_password') ?? ''; 

      // Validamos que la sesión exista
      if (loggedEmail.isEmpty || loggedPassword.isEmpty) {
        _mostrarMensaje('Sesión Inválida', 'No se encontraron las credenciales. Vuelve a iniciar sesión.', Colors.red);
        return;
      }

      // Ya no validamos si el correo coincide.
      // Disparamos directo la petición con la sesión activa y pasamos el texto del QR
      _mostrarMensajeCarga(); 
      await _validarRegistroConAPI(loggedEmail, loggedPassword, qrData);

    } catch (e) {
      _mostrarMensaje('Error', 'Ocurrió un problema al procesar la cámara.', Colors.red);
    }
  }

  // --- 2. FLUJO COMPLETO: API REST ---
  Future<void> _validarRegistroConAPI(String email, String password, String contenidoQR) async {
    final urlAuth = Uri.parse('https://controldeasistenciastec.com/2sis/web/api/users/authentication'); 
    final urlAsistencia = Uri.parse('https://controldeasistenciastec.com/2sis/web/api/asistencias/registrar');

    print('--- PASO 1: Autenticando usuario ---');

    try {
      // 1. PRIMERA PETICIÓN
      final respuestaAuth = await http.post(
        urlAuth,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (respuestaAuth.statusCode == 200 || respuestaAuth.statusCode == 201) {
        final datosRespuesta = json.decode(respuestaAuth.body);
        final String numeroEmpleadoReal = datosRespuesta['numero_empleado'].toString();
        
        print('--- AUTENTICACIÓN EXITOSA ---');
        print('Número de empleado obtenido: $numeroEmpleadoReal');
        print('--- PASO 2: Enviando registro de asistencia ---');

        String fechaHoraFormateada = DateTime.now().toString().split('.').first.replaceAll('-', '/');

        // 2. SEGUNDA PETICIÓN
        final respuestaAsistencia = await http.post(
          urlAsistencia,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode({
            'datetime': fechaHoraFormateada,
            'deviceId': '541657958', 
            'employeeNumber': numeroEmpleadoReal, 
            'serviceKey': '226BRF1JQY', 
          }),
        );

        if(mounted) Navigator.pop(context); // Quitamos el diálogo de carga

        if (respuestaAsistencia.statusCode == 200 || respuestaAsistencia.statusCode == 201) {
          print("--- ASISTENCIA REGISTRADA CORRECTAMENTE ---");
          
          // Mostramos la ventana con la info del QR y esperamos a que se cierre
          await _mostrarDialogoExito(contenidoQR);
          
          // Volvemos a encender la cámara para el siguiente empleado/registro
          setState(() => _estaProcesando = false);
          cameraController.start();

        } else {
          _mostrarMensaje(
            'Error al Registrar', 
            'Código: ${respuestaAsistencia.statusCode}\nDetalle: ${respuestaAsistencia.body}', 
            Colors.orange
          );
          print("Error en registro: ${respuestaAsistencia.body}");
        }

      } else {
        if(mounted) Navigator.pop(context);
        _mostrarMensaje(
          'Credenciales Incorrectas', 
          'No se pudo autenticar el usuario de la sesión en la API.', 
          Colors.red
        );
      }

    } catch (e) {
      if(mounted) Navigator.pop(context);
      _mostrarMensaje('Fallo de Conexión', 'Ocurrió un error de red: $e', Colors.red);
      print("Excepción: $e");
    } finally {
      // Liberamos el candado por si ocurre un error y no se reactiva arriba
      if (_estaProcesando) {
        setState(() => _estaProcesando = false);
      }
    }
  }
  
  // --- 3. NUEVA VENTANA EMERGENTE ---
  Future<void> _mostrarDialogoExito(String datosDelQR) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              SizedBox(height: 15),
              Text('¡Asistencia Registrada!', textAlign: TextAlign.center),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tu entrada se ha procesado exitosamente.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Información del QR:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Text(
                  datosDelQR,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Aceptar', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- MENSAJES DE UTILIDAD ---
  void _mostrarMensajeCarga() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Validando en servidor..."),
          ],
        ),
      ),
    );
  }

  void _mostrarMensaje(String titulo, String mensaje, Color color) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              cameraController.start(); 
            },
            child: const Text('Entendido'),
          )
        ],
      ),
    );
  }

  // --- INTERFAZ GRÁFICA ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escáner de Asistencia'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _procesarQR(barcode.rawValue!);
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
        ],
      ),
    );
  }
}