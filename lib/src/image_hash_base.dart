import 'dart:typed_data';
import 'package:image_hash/src/enums.dart';

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
  /// The hash value.
  int hash;

  /// The hash function.
  final HashFn fn;

  ImageHash(this.hash, this.fn);

  /// Create an image hash from a hex string.
  factory ImageHash.fromHex(String hexString, HashFn kind) {
    if (hexString.length != 16) {
      throw ArgumentError('Hash hex string must be 16 characters (64 bits)');
    }
    return ImageHash(int.parse(hexString, radix: 16), kind);
  }

  /// Create an image hash from a string.
  ///
  /// eg.: 'average:0000000000000000'
  factory ImageHash.fromString(String hashString) {
    final parts = hashString.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid hash string format');
    }
    final kind = HashFn.fromString(parts[0]);
    if (kind == null) {
      throw ArgumentError('Invalid hash kind: ${parts[0]}');
    }
    return ImageHash.fromHex(parts[1], kind);
  }

  /// Create from [Uint8List]
  factory ImageHash.fromBytes(Uint8List bytes, HashFn kind) {
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
    if (fn != other.fn) {
      throw ArgumentError(
          'Image hash kind mismatch: ${fn.name} vs ${other.fn.name}');
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

  /// eg.: 'average:0000000000000000'
  @override
  String toString() {
    return '${fn.name}:${hash.toRadixString(16).padLeft(16, '0')}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageHash && other.hash == hash && other.fn == fn;
  }

  @override
  int get hashCode => Object.hash(hash, fn);
}
