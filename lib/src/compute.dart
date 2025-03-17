import 'dart:math' as math;

import 'package:image/image.dart';
import 'package:image_hash/image_hash.dart';

/// Image hash caclulator.
abstract final class ImageHasher {
  /// Calculate the average hash of an image.
  static ImageHash average(Image img, {int size = 8}) {
    if (size * size > 64) {
      throw ArgumentError(
          'Size too large: resulting hash would exceed 64 bits');
    }

    final ahash = ImageHash(0, HashFn.average);

    // Resize the image
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
  static ImageHash difference(
    Image img, {
    HashDirection direction = HashDirection.horizontal,
    int size = 8,
  }) {
    final dhash = ImageHash(0, HashFn.difference);

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
    if (direction == HashDirection.horizontal ||
        direction == HashDirection.both) {
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
    if (direction == HashDirection.vertical ||
        direction == HashDirection.both) {
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
  static ImageHash median(Image img, {int size = 8}) {
    if (size * size > 64) {
      throw ArgumentError(
          'Size too large: resulting hash would exceed 64 bits');
    }

    final mhash = ImageHash(0, HashFn.median);

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
        : (pixelValues[pixelValues.length ~/ 2 - 1] +
                pixelValues[pixelValues.length ~/ 2]) ~/
            2;

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
  static ImageHash wavelet(Image img, {int size = 8}) {
    final whash = ImageHash(0, HashFn.wavelet);

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
  static ImageHash perceptual(Image img, {int size = 32}) {
    if (size < 8) {
      throw ArgumentError('Size must be at least 8');
    }

    final phash = ImageHash(0, HashFn.perceptual);

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
  static List<double> _applyDCTAndGetLowFreq(
      List<double> pixels, int width, int height) {
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
        n,
        (k) => List<double>.generate(
            n, (i) => math.cos((math.pi / n) * (i + 0.5) * k)));

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
      ImageHash targetHash, List<ImageHash> hashes) {
    return hashes.map((hash) => targetHash.similarity(hash)).toList();
  }

  /// Batch version of [ImageHash.distance]
  static List<int> batchCompareDistance(
      ImageHash targetHash, List<ImageHash> hashes) {
    return hashes.map((hash) => targetHash.distance(hash)).toList();
  }
}
