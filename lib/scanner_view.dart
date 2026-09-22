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

// --- 1. PROCESAMIENTO DEL QR (App Empleado) ---
 Future<void> _procesarQR(String qrData) async {
    if (_estaProcesando) return;
    setState(() => _estaProcesando = true);
    
    cameraController.stop(); // Pausamos la cámara

    try {
      print('--- LECTURA CRUDA DEL QR ---');
      print(qrData);
      
      // 1. Desempaquetar el JSON
      final Map<String, dynamic> datosDelQR = json.decode(qrData);
      
      final String ipTablet = datosDelQR['ip'] ?? '';
      final int puertoTablet = datosDelQR['puerto'] ?? 8080;
      final int timestampQR = datosDelQR['ts'] ?? 0;

      if (ipTablet.isEmpty || timestampQR == 0) {
        _mostrarMensaje('Error', 'Formato de QR inválido.', Colors.red);
        return;
      }

      // 2. Validación de tiempo (Relajada para pruebas)
      final int tiempoActualMs = DateTime.now().millisecondsSinceEpoch;
      final int diferenciaMs = tiempoActualMs - timestampQR;
      
      print('--- Diferencia de tiempo: $diferenciaMs milisegundos ---');

      // ⚠️ Ampliado a 60,000 ms (1 minuto) por si los relojes están desincronizados
      if (diferenciaMs > 60000 || diferenciaMs < -60000) {
        print('❌ BARRERA ACTIVA: El código expiró');
        _mostrarMensaje('QR Expirado', 'El código ha caducado. Diferencia: ${diferenciaMs}ms', Colors.red);
        return;
      }

      // 3. Tomar credenciales
      final prefs = await SharedPreferences.getInstance();
      final numeroEmpleado = prefs.getString('numero_empleado') ?? '';

      print('--- Número de empleado en memoria: "$numeroEmpleado" ---');

      if (numeroEmpleado.isEmpty) {
        print('❌ BARRERA ACTIVA: Sesión vacía');
        _mostrarMensaje('Sesión Inválida', 'No hay sesión activa. Vuelve a iniciar sesión.', Colors.red);
        return;
      }

      _mostrarMensajeCarga(); 
      
      // 4. Enviar los datos
      await _validarRegistroConTablet(numeroEmpleado, ipTablet, puertoTablet, qrData);

    } on FormatException {
      _mostrarMensaje('QR Inválido', 'Este código no pertenece al sistema.', Colors.red);
    } catch (e) {
      _mostrarMensaje('Error', 'Ocurrió un problema al leer el QR.', Colors.red);
    }
  }
  // --- 2. COMUNICACIÓN LAN CON LA TABLET ---
  Future<void> _validarRegistroConTablet(String numEmpleado, String ip, int puerto, String contenidoQR) async {
    // 🚀 ATENCIÓN: Apuntamos a la Tablet en la red Wi-Fi local.
    final urlLocalTablet = Uri.parse('http://$ip:$puerto/registrar');

    print('--- Enviando asistencia a la Tablet: $urlLocalTablet ---');

    try {
      String fechaHoraFormateada = DateTime.now().toString().split('.').first.replaceAll('-', '/');

      // Solo mandamos lo que la Tablet necesita para armar el paquete final
      final respuestaTablet = await http.post(
        urlLocalTablet,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'datetime': fechaHoraFormateada,
          'employeeNumber': numEmpleado,
        }),
      ).timeout(const Duration(seconds: 5)); // Timeout corto por si usa datos móviles

      if(mounted) Navigator.pop(context); // Quitamos diálogo de carga

      if (respuestaTablet.statusCode == 200 || respuestaTablet.statusCode == 201) {
        print("--- LA TABLET ACEPTÓ EL REGISTRO ---");
        
        await _mostrarDialogoExito(contenidoQR);
        
        setState(() => _estaProcesando = false);
        cameraController.start();
      } else {
        // La tablet rechazó el registro o el servidor de internet falló
        final errorDecode = json.decode(respuestaTablet.body);
        _mostrarMensaje('Error de Registro', errorDecode['mensaje'] ?? 'La tablet rechazó el registro.', Colors.orange);
      }
    } catch (e) {
      if(mounted) Navigator.pop(context);
      
      // Si el empleado usa datos móviles, la petición caerá aquí por "Timeout"
      _mostrarMensaje(
        'Fallo de Red Wi-Fi', 
        'No se pudo encontrar la Tablet. Asegúrate de estar conectado a la misma red Wi-Fi de la oficina y no usar datos móviles.', 
        Colors.red
      );
      print("Excepción Local: $e");
    } finally {
      if (_estaProcesando) setState(() => _estaProcesando = false);
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
            Text("Conectando con la Tablet..."),
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