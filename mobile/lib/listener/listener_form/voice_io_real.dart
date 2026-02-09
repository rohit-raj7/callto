// Real implementations for mobile platforms (uses dart:io)

import 'dart:io';
import 'dart:typed_data';

/// Check if a file exists at the given path
bool fileExists(String path) => File(path).existsSync();

/// Read file bytes from path
Uint8List readFileBytes(String path) => File(path).readAsBytesSync();

/// Get app documents directory path
/// Note: On mobile, we use a simple fallback. The voice_selection_page
/// will provide the real path via path_provider when recording.
String getAppDocumentsPath() => Directory.systemTemp.path;
