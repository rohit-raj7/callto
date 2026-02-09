// Stub implementations for web platform (no dart:io)

import 'dart:typed_data';

/// Check if a file exists at the given path (web: always false)
bool fileExists(String path) => false;

/// Read file bytes from path (web: throws — should not be called)
Uint8List readFileBytes(String path) {
  throw UnsupportedError('Cannot read files on web platform');
}

/// Get app documents directory path (web: returns empty string)
String getAppDocumentsPath() => '';
