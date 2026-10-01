class DebugLogger {
  static void api(String message) {
    print('[API] $message');
  }

  static void auth(String message) {
    print('[AUTH] $message');
  }

  static void data(String message) {
    print('[DATA] $message');
  }

  static void error(String message, [Object? error]) {
    print('[ERROR] $message');
    if (error != null) {
      print('[ERROR_DETAIL] $error');
    }
  }
}