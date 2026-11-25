/// Base de la API del servidor; se configura al compilar con --dart-define.
/// Se comparte entre autenticación, renovación y registro directo.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  
  defaultValue: 'https://controldeasistenciastec.com/2sis/web/api',
  //defaultValue: 'https://controldeasistenciastec.com/2sis/web/api/asistencias/registrar'
  //defaultValue: 'http://192.168.1.16/horaexactaapp/web/api',
);

Uri apiEndpoint(String path) {
  final base = apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  return Uri.parse('$base/$path');
}

Uri get authenticationUrl => apiEndpoint('users/authentication');
Uri get refreshTokenUrl => apiEndpoint('users/authentication/refresh-token');
Uri get attendanceUrl => apiEndpoint('asistencias/registrar');
