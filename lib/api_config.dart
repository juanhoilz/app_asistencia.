/// Base de la API del servidor; se configura al compilar con --dart-define.
/// No se utiliza para la comunicación con la tablet indicada por el QR.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.52/horaexactaapp/web/api',
);

Uri get authenticationUrl {
  final base = apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  return Uri.parse('$base/users/authentication');
}
