import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart';

/// Platform-specific file reader for IO platforms
abstract final class PlatformFileReader {
  /// Read bytes from a file path
  static Future<Uint8List> readBytes(String path) async {
    return await File(path).readAsBytes();
  }

  /// Decode an image from a file path
  static Future<Image?> decodeImageFromPath(String path) async {
    final bytes = await readBytes(path);
    return decodeImage(bytes);
  }
}

/// IO-specific directory handling
abstract final class PlatformDirectory {
  /// List files in a directory with the given extensions
  static Future<List<String>> listFiles(
    String directoryPath, {
    List<String> extensions = const [],
    bool recursive = false,
  }) async {
    final directory = Directory(directoryPath);
    final files = await directory
        .list(recursive: recursive)
        .where((e) =>
            e is File &&
            (extensions.isEmpty ||
                extensions.any((ext) => e.path.toLowerCase().endsWith(ext))))
        .cast<File>()
        .map((file) => file.path)
        .toList();

    return files;
  }
}
