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

  Future<void> _procesarQR(String qrData) async {
    if (_estaProcesando) return;
    setState(() => _estaProcesando = true);
    
    cameraController.stop(); // Pausamos la cámara

    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedEmail = prefs.getString('logged_email') ?? '';
      
      // Separamos la información del QR (Esperamos: correo,contraseña)
      List<String> datosQR = qrData.split(',');
      if (datosQR.length < 2) throw Exception("Formato de QR no válido");

      String qrEmail = datosQR[0].trim();
      String qrPassword = datosQR[1].trim(); 

      // Validamos la regla de negocio: ¿Es el mismo usuario logeado?
      if (qrEmail == loggedEmail) {
        // Coincide el usuario. Ahora mandamos a validar contra la API de Postman
        _mostrarMensajeCarga(); // Mostramos un diálogo de carga
        await _validarRegistroConAPI(qrEmail, qrPassword);
      } else {
        _mostrarMensaje('Denegado', 'El código QR no pertenece al usuario que inició sesión ($loggedEmail).', Colors.red);
      }
    } catch (e) {
      _mostrarMensaje('Error de lectura', 'Asegúrate de que el QR contenga correo y contraseña separados por coma.', Colors.red);
    }
  }

  // --- PETICIÓN REAL A LA API REST ---
  Future<void> _validarRegistroConAPI(String email, String password) async {
    // Exactamente la URL que te dieron en Postman
    final url = Uri.parse('https://controldeasistenciastec.com/sandbox/web/api/users/authentication'); 
    
    try {
      final respuesta = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json', // Le decimos a la API que enviamos JSON
          'Accept': 'application/json',       // Esperamos recibir JSON
        },
        // Armamos el Body idéntico a image_69cffd.png
        body: json.encode({
          'email': email,
          'password': password
        }),
      );

      // Quitamos el diálogo de carga
      if(mounted) Navigator.pop(context); 

      if (respuesta.statusCode == 200) {
        // Si responde 200, la API aceptó los datos
        final data = json.decode(respuesta.body);
        
        // Extraemos info de la respuesta de la API (Igual a Postman)
        String noEmpleado = data['numero_empleado'] ?? 'Desconocido';
        
        _mostrarMensaje(
          '¡Asistencia Válida!', 
          'Registro correcto en servidor.\nNúmero de empleado: $noEmpleado', 
          Colors.green
        );
        
        // Opcional: Imprimir el token en la terminal de VS Code para que lo veas
        print("--- CONEXIÓN EXITOSA ---");
        print("Token: ${data['access_token']}");
        
      } else {
        // Si el servidor responde un error (ej. 401 Credenciales incorrectas)
        _mostrarMensaje('Error del Servidor', 'La API rechazó el registro. Código: ${respuesta.statusCode}', Colors.orange);
      }
    } catch (e) {
      if(mounted) Navigator.pop(context); // Quitamos carga
      _mostrarMensaje('Fallo de Conexión', 'No se pudo conectar a la API. Revisa tu internet.', Colors.red);
    } finally {
      setState(() => _estaProcesando = false);
    }
  }

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
              cameraController.start(); // Reactivamos cámara para otro intento
            },
            child: const Text('Entendido'),
          )
        ],
      ),
    );
  }

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