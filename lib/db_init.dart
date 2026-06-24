import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Initialize database factory.
/// Desktop (Windows/Linux/macOS) need sqflite_common_ffi initialization.
/// Android/iOS use native sqflite (no initialization needed).
void initDatabase() {
  final isMobile = Platform.isAndroid || Platform.isIOS;
  if (!isMobile) {
    ffi.sqfliteFfiInit();
  }
}
