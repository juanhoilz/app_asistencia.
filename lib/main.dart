import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'api_config.dart';
import 'scanner_view.dart';
import 'login_style.dart';

void main() {
  runApp(const MiAppAsistencia());
}

class MiAppAsistencia extends StatelessWidget {
  const MiAppAsistencia({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Asistencia',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (_isLoading) return;
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, llena todos los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🚀 1. Hacemos login real contra la API para obtener tu número de empleado
      final url = authenticationUrl;
      final respuesta = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'email': email, 'password': password}),
      );

      if (respuesta.statusCode == 200 || respuesta.statusCode == 201) {
        final datos = json.decode(respuesta.body);
        final String numeroEmpleado = datos['numero_empleado'].toString();

        // 🚀 2. Guardamos tu correo y tu número en la memoria del teléfono
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('logged_email', email);
        await prefs.setString('numero_empleado', numeroEmpleado);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ScannerScreen()),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credenciales incorrectas'),
            backgroundColor: LoginColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fallo de red al iniciar sesión.'),
          backgroundColor: LoginColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: LoginColors.border),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: LoginColors.primary,
          primary: LoginColors.primary,
          surface: Colors.white,
          onSurface: LoginColors.graphite,
          error: LoginColors.error,
          brightness: Brightness.light,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: const TextStyle(
            color: LoginColors.secondary,
            fontSize: 16,
          ),
          floatingLabelStyle: const TextStyle(
            color: LoginColors.secondary,
            fontSize: 16,
          ),
          prefixIconColor: LoginColors.secondary,
          suffixIconColor: LoginColors.secondary,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          border: border,
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: LoginColors.primary, width: 2),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: LoginColors.pearl,
        body: LoginSurface(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: LoginColors.graphite,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Image.asset(
                'assets/images/icono-qr-logomovil.png',
                fit: BoxFit.contain,
                semanticLabel: 'Logo de la aplicación',
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Acceso Administrativo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LoginColors.graphite,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 36),
            TextField(
              controller: _emailController,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              autocorrect: false,
              style: const TextStyle(fontSize: 16, color: LoginColors.graphite),
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _iniciarSesion(),
              style: const TextStyle(fontSize: 16, color: LoginColors.graphite),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  onPressed: _isLoading
                      ? null
                      : () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return LoginColors.primary.withValues(alpha: 0.6);
                    }
                    if (states.contains(WidgetState.pressed)) {
                      return LoginColors.pressed;
                    }
                    return LoginColors.primary;
                  }),
                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                ),
                onPressed: _isLoading ? null : _iniciarSesion,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                          semanticsLabel: 'Iniciando sesión',
                        ),
                      )
                    : const Text(
                        'Continuar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
