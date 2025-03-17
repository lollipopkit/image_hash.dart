import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart';

/// All kinds of hash.
enum HashKind {
  average,
  perceptual,
  difference,
  wavelet,
  median,;

  static HashKind? fromString(String name) {
    for (final kind in values) {
      if (kind.name == name) {
        return kind;
      }
    }
    return null;
  }
}

/// Hash direction for directional hash algorithms
enum HashDirection {
  horizontal,
  vertical,
  both,
}

/// The base class for image hash.
/// 
/// Usage:
/// ```dart
/// final hash = ImageHash.fromString('average:0000000000000000');
/// print(hash.kind); // HashKind.average
/// print(hash.hash); // 0
/// print(hash.bits()); // 64
/// ```
class ImageHash {
  int hash;
  final HashKind kind;

  ImageHash(this.hash, this.kind);

  /// Create an image hash from a hex string.
  factory ImageHash.fromHex(String hexString, HashKind kind) {
    if (hexString.length != 16) {
      throw ArgumentError('Hash hex string must be 16 characters (64 bits)');
    }
    return ImageHash(int.parse(hexString, radix: 16), kind);
  }

  /// Create an image hash from a string.
  factory ImageHash.fromString(String hashString) {
    final parts = hashString.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid hash string format');
    }
    final kind = HashKind.fromString(parts[0]);
    if (kind == null) {
      throw ArgumentError('Invalid hash kind: ${parts[0]}');
    }
    return ImageHash.fromHex(parts[1], kind);
  }

  /// Create from [Uint8List]
  factory ImageHash.fromBytes(Uint8List bytes, HashKind kind) {
    if (bytes.length != 8) {
      throw ArgumentError('Hash bytes must be 8 bytes (64 bits)');
    }
    final byteData = ByteData.view(bytes.buffer);
    return ImageHash(byteData.getUint64(0, Endian.big), kind);
  }

  /// Returns the number of bits in the hash.
  int bits() => 64;

  /// Calculate the hamming distance between two hashes.
  int distance(ImageHash other) {
    if (kind != other.kind) {
      throw ArgumentError('Image hash kind mismatch: ${kind.name} vs ${other.kind.name}');
    }

    final hamming = hash ^ other.hash;
    return _popcnt(hamming);
  }

  /// Calculate the similarity between two hashes.
  /// 
  /// Range: 0.0 (completely different) to 1.0 (identical).
  double similarity(ImageHash other) {
    final dist = distance(other);
    return 1.0 - (dist / 64.0);
  }

  /// Check if two hashes are similar.
  /// 
  /// - [threshold] 0.0 to 1.0, the minimum similarity required.
  bool isSimilar(ImageHash other, {double threshold = 0.9}) {
    return similarity(other) >= threshold;
  }

  /// Calculate the 1-bit count of an integer (Brian Kernighan).
  int _popcnt(int x) {
    int count = 0;
    int value = x;
    
    while (value != 0) {
      value &= (value - 1); // Clear the least significant bit set
      count++;
    }
    
    return count;
  }

  /// Set the bit at the specified index.
  void setBit(int idx) {
    if (idx < 0 || idx >= 64) {
      throw RangeError('Bit index out of range: $idx');
    }
    hash |= 1 << idx;
  }

  /// Get the bit at the specified index.
  bool getBit(int idx) {
    if (idx < 0 || idx >= 64) {
      throw RangeError('Bit index out of range: $idx');
    }
    return (hash & (1 << idx)) != 0;
  }

  /// Convert to [Uint8List]
  Uint8List toBytes() {
    final buffer = Uint8List(8);
    final byteData = ByteData.view(buffer.buffer);
    byteData.setUint64(0, hash, Endian.big);
    return buffer;
  }

  @override
  String toString() {
    return '${kind.name}:${hash.toRadixString(16).padLeft(16, '0')}';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageHash && other.hash == hash && other.kind == kind;
  }

  @override
  int get hashCode => Object.hash(hash, kind);
}

/// Image hash caclulator.
class ImageHasher {
  /// Calculate the average hash of an image.
  static ImageHash averageHash(Image img, {int size = 8}) {
    if (size * size > 64) {
      throw ArgumentError('Size too large: resulting hash would exceed 64 bits');
    }
    
    final ahash = ImageHash(0, HashKind.average);

    // Resize the image to 8x8
    final resized = copyResize(img, width: size, height: size);

    // Convert to grayscale
    final grayImg = grayscale(resized);

    // Calculate the average pixel value
    double sum = 0.0;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final pixelValue = grayImg.getPixel(x, y);
        sum += pixelValue.g.toDouble();
      }
    }
    final avg = sum / (size * size);

    // Build the hash
    int idx = 0;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (idx >= 64) break; // Ensure we don't exceed 64 bits
        final pixelValue = grayImg.getPixel(x, y);
        if (pixelValue.g > avg) {
          ahash.setBit(63 - idx);
        }
        idx++;
      }
    }

    return ahash;
  }

  /// Calculate the difference hash of an image.
  static ImageHash differenceHash(
    Image img, {
    HashDirection direction = HashDirection.horizontal,
    int size = 8,
  }) {
    final dhash = ImageHash(0, HashKind.difference);
    
    int width, height;
    if (direction == HashDirection.horizontal) {
      width = size + 1;
      height = size;
    } else if (direction == HashDirection.vertical) {
      width = size;
      height = size + 1;
    } else {
      // If bidirectional, we need to ensure the total bits do not exceed 64
      // Horizontal (size x (size-1)) + Vertical ((size-1) x size) = 2*size*(size-1)
      // Must be <= 64
      if (2 * size * (size - 1) > 64) {
        throw ArgumentError('Size too large for bidirectional hash');
      }
      width = height = size;
    }

    // Resize the image
    final resized = copyResize(img, width: width, height: height);

    // Convert to grayscale
    final grayImg = grayscale(resized);

    int idx = 0;

    // Horizontal
    if (direction == HashDirection.horizontal || direction == HashDirection.both) {
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < width - 1; x++) {
          if (idx >= 64) break; // Ensure we don't exceed 64 bits
          final left = grayImg.getPixel(x, y).g;
          final right = grayImg.getPixel(x + 1, y).g;
          if (left < right) {
            dhash.setBit(63 - idx);
          }
          idx++;
        }
      }
    }

    // Vertical
    if (direction == HashDirection.vertical || direction == HashDirection.both) {
      for (int x = 0; x < size; x++) {
        for (int y = 0; y < height - 1; y++) {
          if (idx >= 64) break; // Ensure we don't exceed 64 bits
          final top = grayImg.getPixel(x, y).g;
          final bottom = grayImg.getPixel(x, y + 1).g;
          if (top < bottom) {
            dhash.setBit(63 - idx);
          }
          idx++;
        }
      }
    }

    return dhash;
  }

  /// Calculate the median hash of an image
  static ImageHash medianHash(Image img, {int size = 8}) {
    if (size * size > 64) {
      throw ArgumentError('Size too large: resulting hash would exceed 64 bits');
    }
    
    final mhash = ImageHash(0, HashKind.median);

    // Resize the image to 8x8
    final resized = copyResize(img, width: size, height: size);

    // Convert to grayscale
    final grayImg = grayscale(resized);

    // Get all pixel values
    final pixelValues = <int>[];
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        pixelValues.add(grayImg.getPixel(x, y).g.toInt());
      }
    }

    // Calculate median
    pixelValues.sort();
    final median = pixelValues.length.isOdd 
        ? pixelValues[pixelValues.length ~/ 2]
        : (pixelValues[pixelValues.length ~/ 2 - 1] + pixelValues[pixelValues.length ~/ 2]) ~/ 2;

    // Build the hash
    int idx = 0;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (idx >= 64) break; // Ensure we don't exceed 64 bits
        final pixelValue = grayImg.getPixel(x, y);
        if (pixelValue.g >= median) {
          mhash.setBit(63 - idx);
        }
        idx++;
      }
    }

    return mhash;
  }

  /// Calculate the wavelet hash of an image.
  static ImageHash waveletHash(Image img, {int size = 8}) {
    final whash = ImageHash(0, HashKind.wavelet);

    // Resize the image
    final resized = copyResize(img, width: size, height: size);

    // Convert to grayscale
    final grayImg = grayscale(resized);

    // Convert to double array for wavelet transform
    final pixels = List<double>.filled(size * size, 0);
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final pixelValue = grayImg.getPixel(x, y);
        pixels[y * size + x] = pixelValue.g.toDouble();
      }
    }

    // Apply Haar wavelet transform
    final transformed = _applyHaarWavelet(pixels, size);

    // Calculate the median of low frequency components
    final lowFreq = List<double>.filled(64, 0);
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        lowFreq[y * 8 + x] = transformed[y * size + x];
      }
    }
    final median = _medianOfPixels(lowFreq);

    // Build the hash
    for (int i = 0; i < 64; i++) {
      if (lowFreq[i] > median) {
        whash.setBit(63 - i);
      }
    }

    return whash;
  }

  /// Apply Haar wavelet transform to the image
  static List<double> _applyHaarWavelet(List<double> pixels, int size) {
    final result = List<double>.from(pixels);
    
    // Apply to rows
    for (int y = 0; y < size; y++) {
      final row = result.sublist(y * size, (y + 1) * size);
      final transformedRow = _haarTransform1D(row);
      for (int x = 0; x < size; x++) {
        result[y * size + x] = transformedRow[x];
      }
    }
    
    // Apply to columns
    for (int x = 0; x < size; x++) {
      final col = List<double>.filled(size, 0);
      for (int y = 0; y < size; y++) {
        col[y] = result[y * size + x];
      }
      
      final transformedCol = _haarTransform1D(col);
      for (int y = 0; y < size; y++) {
        result[y * size + x] = transformedCol[y];
      }
    }
    
    return result;
  }

  /// 1D Haar wavelet transform
  static List<double> _haarTransform1D(List<double> input) {
    final n = input.length;
    final output = List<double>.filled(n, 0);
    
    int length = n;
    while (length >= 2) {
      for (int i = 0; i < length ~/ 2; i++) {
        output[i] = (input[2 * i] + input[2 * i + 1]) / 2.0;
        output[i + length ~/ 2] = (input[2 * i] - input[2 * i + 1]) / 2.0;
      }
      
      // Copy the transformed values back to input for the next iteration
      for (int i = 0; i < length; i++) {
        input[i] = output[i];
      }
      
      length ~/= 2;
    }
    
    return output;
  }

  /// Calculate the perceptual hash of an image.
  static ImageHash perceptualHash(Image img, {int size = 32}) {
    if (size < 8) {
      throw ArgumentError('Size must be at least 8');
    }
    
    final phash = ImageHash(0, HashKind.perceptual);

    // Resize the image
    final resized = copyResize(img, width: size, height: size);

    // Convert to grayscale
    final grayImg = grayscale(resized);

    // Calculate the pixel values
    final pixels = List<double>.filled(size * size, 0);
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final pixelValue = grayImg.getPixel(x, y);
        pixels[y * size + x] = pixelValue.g.toDouble();
      }
    }

    // Apply DCT and get the low frequency part
    final lowFreq = _applyDCTAndGetLowFreq(pixels, size, size);

    // Calculate the median, excluding the DC component (the first element)
    final valuesForMedian = lowFreq.sublist(1);
    final median = _medianOfPixels(valuesForMedian);

    // Build the hash - skip the first element (DC component)
    for (int i = 1; i < 65; i++) {
      if (i < lowFreq.length && lowFreq[i] > median) {
        phash.setBit(64 - i);
      }
    }

    return phash;
  }

  /// Apply DCT and get the low frequency part
  static List<double> _applyDCTAndGetLowFreq(List<double> pixels, int width, int height) {
    // Apply DCT to each row
    for (int y = 0; y < height; y++) {
      final row = pixels.sublist(y * width, (y + 1) * width);
      final dctRow = _applyDCT1D(row);
      for (int x = 0; x < width; x++) {
        pixels[y * width + x] = dctRow[x];
      }
    }

    // Apply DCT to each column
    for (int x = 0; x < width; x++) {
      final col = List<double>.filled(height, 0);
      for (int y = 0; y < height; y++) {
        col[y] = pixels[y * width + x];
      }

      final dctCol = _applyDCT1D(col);
      for (int y = 0; y < height; y++) {
        pixels[y * width + x] = dctCol[y];
      }
    }

    // Extract the top-left 8x8 area (low frequency part)
    final lowFreq = List<double>.filled(64, 0);
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        lowFreq[y * 8 + x] = pixels[y * width + x];
      }
    }

    return lowFreq;
  }

  /// 1-Dimension Discrete Cosine Transform(DCT)
  static List<double> _applyDCT1D(List<double> input) {
    final n = input.length;
    final output = List<double>.filled(n, 0);
    
    // Precompute the cosine table
    final cosTable = List<List<double>>.generate(
        n, (k) => List<double>.generate(n, (i) => math.cos((math.pi / n) * (i + 0.5) * k)));

    for (int k = 0; k < n; k++) {
      double sum = 0.0;
      for (int i = 0; i < n; i++) {
        sum += input[i] * cosTable[k][i];
      }

      sum *= math.sqrt(2 / n);
      if (k == 0) {
        sum *= 1 / math.sqrt(2);
      }

      output[k] = sum;
    }

    return output;
  }

  /// Calculate the median of pixels
  static double _medianOfPixels(List<double> pixels) {
    final sorted = List<double>.from(pixels)..sort();

    final length = sorted.length;
    if (length % 2 == 0) {
      return (sorted[length ~/ 2 - 1] + sorted[length ~/ 2]) / 2;
    } else {
      return sorted[length ~/ 2];
    }
  }
  
  /// Batch version of [ImageHash.similarity]
  static List<double> batchCompareSimilarity(
    ImageHash targetHash, 
    List<ImageHash> hashes
  ) {
    return hashes.map((hash) => targetHash.similarity(hash)).toList();
  }
  
  /// Batch version of [ImageHash.distance]
  static List<int> batchCompareDistance(
    ImageHash targetHash, 
    List<ImageHash> hashes
  ) {
    return hashes.map((hash) => targetHash.distance(hash)).toList();
  }
}