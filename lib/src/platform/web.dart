import 'dart:async';
import 'dart:typed_data';

import 'package:image/image.dart';

/// Platform-specific file reader for web platforms
abstract final class PlatformFileReader {
  /// Read bytes from a file path
  static Future<Uint8List> readBytes(String path) async {
    throw UnsupportedError('Unsupported on web platforms');
  }

  /// Decode an image from a file path
  static Future<Image?> decodeImageFromPath(String path) async {
    throw UnsupportedError('Unsupported on web platforms');
  }
}

/// Web-specific directory handling
/// Note: True directory listing isn't possible in browser environments
abstract final class PlatformDirectory {
  /// List files in a directory with the given extensions
  static Future<List<String>> listFiles(
    String directoryPath, {
    List<String> extensions = const [],
    bool recursive = false,
  }) async {
    throw UnsupportedError('Unsupported on web platforms');
  }
}
