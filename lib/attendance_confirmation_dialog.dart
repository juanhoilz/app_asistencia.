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
      child: SingleChildScrollView(
        child: AttendanceResultContent(
          title: pending ? 'Checada guardada' : 'Asistencia registrada',
          message: pending
              ? 'Tu checada está guardada en este dispositivo y está pendiente de envío.'
              : 'Tu asistencia se envió correctamente.',
          icon: pending ? Icons.schedule_rounded : Icons.check_rounded,
          primaryLabel: pending ? 'Entendido' : 'Aceptar',
          onPrimary: () => Navigator.of(context).pop(),
          isDialog: true,
          useIce: pending,
        ),
      ),
    );
  }
}

class AttendanceResultContent extends StatelessWidget {
  const AttendanceResultContent({
    super.key,
    required this.title,
    required this.icon,
    required this.primaryLabel,
    required this.onPrimary,
    this.message,
    this.secondaryAction,
    this.isDialog = false,
    this.useIce = false,
  });

  final String title;
  final IconData icon;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? message;
  final Widget? secondaryAction;
  final bool isDialog;
  final bool useIce;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 372),
        child: DefaultTextStyle.merge(
          textAlign: TextAlign.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: useIce ? LoginColors.ice : LoginColors.turquoise,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 48,
                    color: useIce ? LoginColors.graphite : LoginColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                namesRoute: isDialog,
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: LoginColors.graphite,
                  ),
                ),
              ),
              if (message case final text?) ...[
                const SizedBox(height: 30),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: LoginColors.secondary,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPrimary,
                  style: ButtonStyle(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.disabled)) return null;
                      return states.contains(WidgetState.pressed)
                          ? LoginColors.pressed
                          : LoginColors.primary;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.disabled)
                          ? null
                          : Colors.white,
                    ),
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  child: Text(primaryLabel, textAlign: TextAlign.center),
                ),
              ),
              if (secondaryAction case final action?) ...[
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
