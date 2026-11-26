import 'package:flutter/material.dart';

import 'login_style.dart';

class AttendanceConfirmationDialog extends StatelessWidget {
  const AttendanceConfirmationDialog({super.key, required this.pending});

  final bool pending;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white.withValues(alpha: 0.98),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: LoginColors.graphite.withValues(alpha: 0.16),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Colors.white),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: pending ? LoginColors.ice : LoginColors.turquoise,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    pending ? Icons.schedule_rounded : Icons.check_rounded,
                    size: 48,
                    color: pending ? LoginColors.graphite : LoginColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                namesRoute: true,
                header: true,
                child: Text(
                  pending ? 'Checada guardada' : 'Asistencia registrada',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: LoginColors.graphite,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                pending
                    ? 'Tu checada está guardada en este dispositivo y está pendiente de envío.'
                    : 'Tu asistencia se envió correctamente.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: LoginColors.secondary,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ButtonStyle(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      return states.contains(WidgetState.pressed)
                          ? LoginColors.pressed
                          : LoginColors.primary;
                    }),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  child: Text(pending ? 'Entendido' : 'Aceptar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
