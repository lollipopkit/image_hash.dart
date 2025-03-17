import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart';
import 'package:image_hash/image_hash.dart';

/// Parameters for the similar images isolate
class _SimilarImagesParams {
  final String directoryPath;
  final List<String> exts;
  final int distanceThreshold;

  _SimilarImagesParams({
    required this.directoryPath,
    required this.exts,
    required this.distanceThreshold,
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

  final directory = Directory(params.directoryPath);

  // Get all image files
  sendPort.send(SimilarImagesProgressScanDir());
  final files = await directory
      .list(recursive: true)
      .where(
        (e) =>
            e is File &&
            params.exts.any((ext) => e.path.toLowerCase().endsWith(ext)),
      )
      .cast<File>()
      .toList();

  sendPort.send(SimilarImagesProgressFoundImages(files.length));

  // Calculate hash for all images
  final imageHashes = <String, ImageHash>{};

  for (int i = 0; i < files.length; i++) {
    final file = files[i];
    try {
      sendPort.send(
          SimilarImagesProgressProcessingImage(i + 1, files.length, file.path));
      final img = decodeImage(await file.readAsBytes());
      if (img != null) {
        final hash = ImageHasher.perceptualHash(img);
        imageHashes[file.path] = hash;
      }
    } catch (e) {
      sendPort.send(SimilarImagesProgressErr(e.toString(), file.path));
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
Future<List<SimilarImagesGroup>> findSimilarImages(
  String directoryPath, {
  List<String> exts = const ['.jpg', '.jpeg', '.png'],
  int distanceThreshold = 20,
  void Function(SimilarImagesProgress progress)? onProgress,
}) async {
  // Create ports for communication
  final receivePort = ReceivePort();

  // Define the data to send to the isolate
  final params = _SimilarImagesParams(
    directoryPath: directoryPath,
    exts: exts,
    distanceThreshold: distanceThreshold,
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
