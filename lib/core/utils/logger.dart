import 'package:flutter/foundation.dart';

/// Basit, merkezi bir loglama servisi. Şu an debugPrint'e sarar;
/// ileride Sentry/Crashlytics gibi bir servise kolayca bağlanabilir,
/// bu sayede uygulama genelinde `print` çağrısı dağılmaz.
class AppLogger {
  AppLogger._();

  static void info(String message) {
    if (kDebugMode) debugPrint('ℹ️ [INFO] $message');
  }

  static void warning(String message) {
    if (kDebugMode) debugPrint('⚠️ [WARN] $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('🛑 [ERROR] $message ${error ?? ''}');
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
  }
}
