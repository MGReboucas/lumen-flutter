import 'package:flutter/foundation.dart';

// Browser localhost is not Android emulator's 10.0.2.2.
String get apiBaseUrl {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured.replaceFirst(RegExp(r'/+$'), '');
  if (kIsWeb) {
    final page = Uri.base;
    if (page.host == 'localhost' || page.host == '127.0.0.1') {
      return 'http://${page.host}:8000/api/v1';
    }
    return '${page.origin}/api/v1';
  }
  return defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8000/api/v1'
      : 'http://127.0.0.1:8000/api/v1';
}
