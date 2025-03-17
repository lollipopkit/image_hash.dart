# Image Hash

A Dart library for perceptual image hashing and comparison. This package allows you to generate hash values from images and compare them to determine similarity, making it useful for tasks like finding duplicate or similar images, image recognition, and content-based image retrieval.

## Features

- Multiple hashing algorithms:
  - **Perceptual Hash**: Robust against compression and minor color adjustments
  - **Average Hash**: Fast but less accurate for certain transformations
  - **Difference Hash**: Good at detecting edges (supporting horizontal, vertical, or both directions)
  - **Wavelet Hash**: More accurate but computationally intensive
  - **Median Hash**: Uses median values for improved robustness
- Compare images using distance or similarity metrics
- Batch operations for comparing against multiple images
- Hash conversion to/from hex strings and byte arrays

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  image_hash: ^x.y.z
```

## Usage

### Creating Hashes

```dart
import 'package:image_hash/image_hash.dart';
import 'package:image/image.dart' as img;

void main() {
  // Load an image
  final image = img.decodeImage(File('path/to/image.jpg').readAsBytesSync());
  
  // Generate different types of hashes
  final averageHash = ImageHasher.averageHash(image);
  final perceptualHash = ImageHasher.perceptualHash(image);
  final differenceHash = ImageHasher.differenceHash(image);
  final waveletHash = ImageHasher.waveletHash(image);
  final medianHash = ImageHasher.medianHash(image);
  
  // Custom parameters
  final customDifferenceHash = ImageHasher.differenceHash(
    image,
    direction: HashDirection.both,
    size: 8
  );
}
```

### Hash Conversion

```dart
// Convert hash to hex string
final hash = ImageHasher.averageHash(image);
final hexString = hash.toString();  // Format: "average:1a2b3c4d5e6f7890"

// Create hash from hex string
final newHash = ImageHash.fromHex("1a2b3c4d5e6f7890", HashKind.average);

// Convert to and from bytes
final bytes = hash.toBytes();
final hashFromBytes = ImageHash.fromBytes(bytes, HashKind.average);
```

### Comparing Images

```dart
// Load two images
final image1 = img.decodeImage(File('image1.jpg').readAsBytesSync());
final image2 = img.decodeImage(File('image2.jpg').readAsBytesSync());

// Generate hashes
final hash1 = ImageHasher.perceptualHash(image1);
final hash2 = ImageHasher.perceptualHash(image2);

// Compare using distance (lower means more similar)
int distance = hash1.distance(hash2);  // 0-64 range (0 is identical)

// Compare using similarity (higher means more similar)
double similarity = hash1.similarity(hash2);  // 0.0-1.0 range (1.0 is identical)

// Check if images are similar with a threshold
bool isSimilar = hash1.isSimilar(hash2, threshold: 0.85);
```

### Batch Operations

```dart
// Compare one hash against multiple hashes
final targetHash = ImageHasher.perceptualHash(targetImage);
final hashes = images.map((img) => ImageHasher.perceptualHash(img)).toList();

// Get similarity scores for all images
List<double> similarities = ImageHasher.batchCompareSimilarity(targetHash, hashes);

// Get distances for all images
List<int> distances = ImageHasher.batchCompareDistance(targetHash, hashes);

// Find the most similar image
int mostSimilarIndex = similarities.indexOf(similarities.reduce(math.max));
```

## API Reference

### Classes

- `ImageHash`: Represents a hash value of an image with methods for comparison
- `ImageHasher`: Static methods to generate different types of image hashes

### Enums

- `HashKind`: Defines the type of hash algorithm (average, perceptual, difference, wavelet, median)
- `HashDirection`: Specifies the direction for the difference hash algorithm (horizontal, vertical, both)

## Tips for Best Results

- For general use, `perceptualHash` usually provides the best balance of accuracy and speed
- When comparing images, a similarity threshold between 0.85-0.95 often works well
- The ideal hash algorithm depends on your specific use case:
  - `averageHash`: Best for finding exact duplicates or very similar images
  - `differenceHash`: Good for detecting structural/edge changes
  - `waveletHash`: Best for detecting subtle differences, but slower
  - `medianHash`: More robust against noise than average hash

## License

```
MIT License
```
