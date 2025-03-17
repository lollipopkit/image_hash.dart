import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart';
import 'package:image_hash/image_hash.dart';

/// All kinds of hash.
///
/// Usage:
/// ```dart
/// final hash = HashFn.average.hashFile('sample.jpg');
/// ```
enum HashFn {
  /// Average hash (aHash): Fastest and simplest algorithm.
  /// - Good for: Quick similarity checking
  /// - Pros: Very fast computation
  /// - Cons: Less accurate with high-frequency details
  /// - Sensitivity: Most sensitive to global lighting changes
  average,

  /// Perceptual hash (pHash): More robust than average hash.
  /// - Good for: Detecting visually similar images with different encodings
  /// - Pros: Resistant to compression and minor alterations
  /// - Cons: More complex computation than average hash
  /// - Sensitivity: Less sensitive to global changes, preserves structural details
  perceptual,

  /// Difference hash (dHash): Focuses on gradient directions.
  /// - Good for: Detecting subtle differences between similar images
  /// - Pros: Good at detecting relative differences between adjacent pixels
  /// - Cons: Can be affected by noise in smooth areas
  /// - Sensitivity: Medium sensitivity to local changes
  difference,

  /// Wavelet hash (wHash): Uses wavelet transform for feature extraction.
  /// - Good for: Detailed image analysis with multi-resolution properties
  /// - Pros: Captures both global and local features at multiple scales
  /// - Cons: More computationally intensive
  /// - Sensitivity: Balanced sensitivity to both global and local features
  wavelet,

  /// Median hash (mHash): Uses median values instead of average.
  /// - Good for: Images with outliers or extreme pixel values
  /// - Pros: More robust against outliers than average hash
  /// - Cons: Slightly higher computational cost than average hash
  /// - Sensitivity: Less affected by small bright/dark spots
  median,
  ;

  /// Get [HashFn] from a string.
  static HashFn? fromString(String name) {
    for (final kind in values) {
      if (kind.name == name) {
        return kind;
      }
    }
    return null;
  }

  /// Get the [ImageHash] from an [Image].
  ///
  /// - [size] is the size of calulating the hash, default is 32.
  /// 
  /// Some hash functions have different parameters, see the specific function for details.
  /// eg.: [ImageHasher.difference] has [direction] parameter.
  ImageHash hashImg(Image img, {int size = 16}) {
    return switch (this) {
      HashFn.average => ImageHasher.average(img, size: size),
      HashFn.perceptual => ImageHasher.perceptualHash(img, size: size),
      HashFn.difference => ImageHasher.difference(img, size: size),
      HashFn.wavelet => ImageHasher.wavelet(img, size: size),
      HashFn.median => ImageHasher.median(img, size: size),
    };
  }

  /// Get the [ImageHash] from a file.
  ///
  /// - [size] is the size of calulating the hash, default is 32.
  /// - [decodeImageFn] is the function to decode the image, default is [decodeImage].
  ///
  /// You must ensure the file is an image file.
  Future<ImageHash> hashFile(
    String path, {
    int size = 16,
    Image? Function(Uint8List data, {int? frame})? decodeImageFn,
  }) async {
    decodeImageFn ??= decodeImage;

    final img = decodeImageFn(await File(path).readAsBytes());
    if (img == null) {
      throw Exception('decode image failed');
    }

    return hashImg(img, size: size);
  }
}

/// Hash direction for directional hash algorithms
enum HashDirection {
  /// Horizontal hash
  horizontal,

  /// Vertical hash
  vertical,

  /// Both horizontal and vertical hash
  both,
}
