class ApiConfig {
  static const String host = '172.20.10.13';
  static const int port = 8000;

  static const String baseUrl = 'http://172.20.10.13:8000/api/v1';
  static const String healthUrl = 'http://172.20.10.13:8000/health';

  static const Duration timeout = Duration(seconds: 25);
}
