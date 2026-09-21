import 'package:flutter/foundation.dart';

enum AppLogLevel { debug, info, warning, error }

class AppLogger {
  const AppLogger({this.sink});

  final void Function(String message)? sink;

  void debug(String message) => _write(AppLogLevel.debug, message);

  void info(String message) => _write(AppLogLevel.info, message);

  void warning(String message) => _write(AppLogLevel.warning, message);

  void error(String message, [Object? error]) {
    final suffix = error == null ? '' : ' | $error';
    _write(AppLogLevel.error, '$message$suffix');
  }

  void _write(AppLogLevel level, String message) {
    final line = '[${level.name.toUpperCase()}] $message';
    if (sink != null) {
      sink!(line);
    } else if (kDebugMode) {
      debugPrint(line);
    }
  }
}
