import 'dart:async';
// dart:isolate only on non-web
import 'dart:isolate' if (dart.library.html) '';

import 'package:image_hash/image_hash.dart';

/// Parameters for the similar images isolate
class _SimilarImagesParams {
  final String directoryPath;
  final List<String> exts;
  final int distanceThreshold;
  final HashFn hashFn;

  _SimilarImagesParams({
    required this.directoryPath,
    required this.exts,
    required this.distanceThreshold,
    required this.hashFn,
  });
}

/// Progress updates for the similar images finder
sealed class SimilarImagesProgress {
  /// Format the progress message
  @override
  String toString();
}

/// Is scanning the directory
class SimilarImagesProgressScanDir extends SimilarImagesProgress {
  @override
  String toString() => 'Scanning directory...';
}

/// Found image files
class SimilarImagesProgressFoundImages extends SimilarImagesProgress {
  /// The number of image files found
  final int count;

  SimilarImagesProgressFoundImages(this.count);

  @override
  String toString() => 'Found $count image files';
}

/// Processing an image
class SimilarImagesProgressProcessingImage extends SimilarImagesProgress {
  /// The current image idx being processed
  final int current;

  /// The total number of images
  final int total;

  /// The path of the image being processed
  final String path;

  SimilarImagesProgressProcessingImage(this.current, this.total, this.path);

  @override
  String toString() => 'Processing image $current/$total: $path';
}

/// Comparing images
class SimilarImagesProgressCompare extends SimilarImagesProgress {
  /// The current image idx being compared
  final int current;

  /// The total number of images
  final int total;

  SimilarImagesProgressCompare(this.current, this.total);

  @override
  String toString() => 'Comparing image $current/$total';
}

/// Found similar image groups
class SimilarImagesProgressFoundSimilarGroups extends SimilarImagesProgress {
  /// The number of similar image groups found
  final int count;

  SimilarImagesProgressFoundSimilarGroups(this.count);

  @override
  String toString() => 'Found $count groups of similar images';
}

/// Error processing an image
class SimilarImagesProgressErr extends SimilarImagesProgress {
  /// The error message
  final String message;

  /// The path of the image that caused the error
  final String path;

  SimilarImagesProgressErr(this.message, this.path);

  @override
  String toString() => 'Error of <$path>: $message';
}

/// A group of similar images
typedef SimilarImagesGroup = List<(String, ImageHash)>;

/// Worker function that runs in the isolate
void _findSimilarImagesIsolate(
  (SendPort sendPort, _SimilarImagesParams params) message,
) async {
  final sendPort = message.$1;
  final params = message.$2;

  // Get all image files
  sendPort.send(SimilarImagesProgressScanDir());
  List<String> files;
  try {
    files = await PlatformDirectory.listFiles(
      params.directoryPath,
      extensions: params.exts,
      recursive: true,
    );
  } catch (e) {
    sendPort.send(SimilarImagesProgressErr(e.toString(), params.directoryPath));
    sendPort.send(<SimilarImagesGroup>[]);
    return;
  }

  sendPort.send(SimilarImagesProgressFoundImages(files.length));

  // Calculate hash for all images
  final imageHashes = <String, ImageHash>{};

  for (int i = 0; i < files.length; i++) {
    final filePath = files[i];
    try {
      sendPort.send(
          SimilarImagesProgressProcessingImage(i + 1, files.length, filePath));
      final img = await PlatformFileReader.decodeImageFromPath(filePath);
      if (img != null) {
        final hash = params.hashFn.hashImg(img);
        imageHashes[filePath] = hash;
      }
    } catch (e) {
      sendPort.send(SimilarImagesProgressErr(e.toString(), filePath));
    }
  }

  // Find similar image groups
  final similarGroups = <SimilarImagesGroup>[];
  final processed = <String>{};

  int currentEntry = 0;
  final totalEntries = imageHashes.length;

  for (final entry1 in imageHashes.entries) {
    currentEntry++;
    if (currentEntry % 10 == 0) {
      sendPort.send(SimilarImagesProgressCompare(currentEntry, totalEntries));
    }

    if (processed.contains(entry1.key)) continue;

    final currentGroup = <(String, ImageHash)>[];
    currentGroup.add((entry1.key, entry1.value));
    processed.add(entry1.key);

    for (final entry2 in imageHashes.entries) {
      if (entry1.key == entry2.key || processed.contains(entry2.key)) continue;

      final distance = entry1.value.distance(entry2.value);
      if (distance < params.distanceThreshold) {
        currentGroup.add((entry2.key, entry2.value));
        processed.add(entry2.key);
      }
    }

    // Only add groups with more than one image
    if (currentGroup.length > 1) {
      similarGroups.add(currentGroup);
    }
  }

  sendPort.send(SimilarImagesProgressFoundSimilarGroups(similarGroups.length));

  // Send the final result
  sendPort.send(similarGroups);
}

/// Check all similar imgs under the directory.
///
/// - [directoryPath] is the path of the directory to search for images.
/// - [exts] is extensions, defaults to ['.jpg', '.jpeg', '.png']
/// - [distanceThreshold] is the threshold for the distance between two images. Defaults to 20.
/// Bigger value means less similar images.
/// - [onProgress] is a callback that will be called with progress updates.
///
/// Note: On web platforms, this function requires different usage patterns.
/// In browsers, you need to provide URLs to images or use the File API with user-selected files.
Future<List<SimilarImagesGroup>> findSimilarImages(
  String directoryPath, {
  List<String> exts = const ['.jpg', '.jpeg', '.png'],
  int distanceThreshold = 20,
  void Function(SimilarImagesProgress progress)? onProgress,
  HashFn hashFn = HashFn.perceptual,
}) async {
  // Create ports for communication
  final receivePort = ReceivePort();

  // Define the data to send to the isolate
  final params = _SimilarImagesParams(
    directoryPath: directoryPath,
    exts: exts,
    distanceThreshold: distanceThreshold,
    hashFn: hashFn,
  );

  // Spawn the isolate
  final isolate = await Isolate.spawn(
    _findSimilarImagesIsolate,
    (receivePort.sendPort, params),
  );

  // Handle messages from the isolate
  final completer = Completer<List<List<(String, ImageHash)>>>();

  receivePort.listen((message) {
    if (message is SimilarImagesProgress) {
      // Progress update
      onProgress?.call(message);
    } else if (message is List<List<(String, ImageHash)>>) {
      // Final result
      completer.complete(message);
      receivePort.close();
      isolate.kill();
    }
  });

  return completer.future;
}

/// Web-compatible version to find similar images from a list of image URLs.
///
/// This function is designed for web environments where directory access is not available.
/// - [imageUrls] is the list of image URLs or paths to compare
/// - [distanceThreshold] is the threshold for the distance between two images
/// - [onProgress] is a callback that will be called with progress updates
Future<List<SimilarImagesGroup>> findSimilarImagesWeb(
  List<String> imageUrls, {
  int distanceThreshold = 20,
  void Function(SimilarImagesProgress progress)? onProgress,
}) async {
  onProgress?.call(SimilarImagesProgressFoundImages(imageUrls.length));

  // Calculate hash for all images
  final imageHashes = <String, ImageHash>{};

  for (int i = 0; i < imageUrls.length; i++) {
    final url = imageUrls[i];
    try {
      onProgress?.call(
          SimilarImagesProgressProcessingImage(i + 1, imageUrls.length, url));
      final img = await PlatformFileReader.decodeImageFromPath(url);
      if (img != null) {
        final hash = ImageHasher.perceptual(img);
        imageHashes[url] = hash;
      }
    } catch (e) {
      onProgress?.call(SimilarImagesProgressErr(e.toString(), url));
    }
  }

  // Find similar image groups
  final similarGroups = <SimilarImagesGroup>[];
  final processed = <String>{};

  int currentEntry = 0;
  final totalEntries = imageHashes.length;

  for (final entry1 in imageHashes.entries) {
    currentEntry++;
    if (currentEntry % 10 == 0) {
      onProgress
          ?.call(SimilarImagesProgressCompare(currentEntry, totalEntries));
    }

    if (processed.contains(entry1.key)) continue;

    final currentGroup = <(String, ImageHash)>[];
    currentGroup.add((entry1.key, entry1.value));
    processed.add(entry1.key);

    for (final entry2 in imageHashes.entries) {
      if (entry1.key == entry2.key || processed.contains(entry2.key)) continue;

      final distance = entry1.value.distance(entry2.value);
      if (distance < distanceThreshold) {
        currentGroup.add((entry2.key, entry2.value));
        processed.add(entry2.key);
      }
    }

    // Only add groups with more than one image
    if (currentGroup.length > 1) {
      similarGroups.add(currentGroup);
    }
  }

  onProgress
      ?.call(SimilarImagesProgressFoundSimilarGroups(similarGroups.length));
  return similarGroups;
}
