import 'package:flutter/material.dart';

abstract final class LoginColors {
  static const pearl = Color(0xFFF6F8FA);
  static const ice = Color(0xFFEAF3FA);
  static const turquoise = Color(0xFFDDF3F0);
  static const lavender = Color(0xFFEEEAF7);
  static const graphite = Color(0xFF18252C);
  static const secondary = Color(0xFF52636B);
  static const primary = Color(0xFF007F78);
  static const pressed = Color(0xFF006A64);
  static const border = Color(0xFFC7D2D8);
  static const error = Color(0xFFB42318);
}

class LoginSurface extends StatelessWidget {
  const LoginSurface({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: LoginColors.pearl),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.3,
                  colors: [LoginColors.turquoise, Color(0x00DDF3F0)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1,
                  colors: [LoginColors.ice, Color(0x00EAF3FA)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomRight,
                  radius: 0.95,
                  colors: [LoginColors.lavender, Color(0x00EEEAF7)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 48).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0818252C),
                            blurRadius: 32,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: children,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
