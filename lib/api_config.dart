/// Jedno źródło na URL-e backendu.  
/// Środowisko przełącza komenda:
///   flutter run --dart-define=ENV=local
/// Domyślnie (bez parametru) ładuje się 'prod'.
class ApiConfig {
  // adresy backendu
  static const String _prod   = 'https://ct-backend-texableplum.azurewebsites.net';
  static const String _localAndroid = 'http://10.0.2.2:5260';  // emulator Android
  static const String _localIOS     = 'http://127.0.0.1:5260'; // simulator iOS

  /// Odczyt wartości build-time:
  static final String _env = const String.fromEnvironment(
    'ENV',              // <-- klucz
    defaultValue: 'prod',
  );

  /// Pełny baseUrl wybrany na podstawie ENV
  static String get baseUrl {
    switch (_env) {
      case 'local-ios':
        return _localIOS;
      case 'local':
      case 'local-android':
        return _localAndroid;
      default:
        return _prod;
    }
  }

  /// Buduje Uri z przekazaną ścieżką
  static Uri uri(String path) => Uri.parse('$baseUrl$path');
}
