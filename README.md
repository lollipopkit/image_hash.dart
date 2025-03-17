# Image Hash
This package allows you to generate hash values from images and compare them to determine similarity, making it useful for tasks like finding duplicate or similar images, image recognition, and content-based image retrieval.


## Usage

### Comparing Images

```dart
// Load two images
final image1 = img.decodeImage(await File('image1.jpg').readAsBytes());

// Generate hashes
// ImageHasher.perceptual = HashFn.perceptual.hashImage
final hash1 = await HashFn.perceptual.hashFile(
  'image2.jpg',
  size: 16,
);
final hash2 = ImageHasher.perceptual(image1);

// Compare using distance (lower means more similar)
int distance = hash1.distance(hash2);  // 0-64 range (0 is identical)

// Compare using similarity (higher means more similar)
double similarity = hash1.similarity(hash2);  // 0.0-1.0 range (1.0 is identical)

// Check if images are similar with a threshold
bool isSimilar = hash1.isSimilar(hash2, threshold: 0.85);
```

### Finding Similar Images

```dart
import 'dart:io';
import 'package:image_hash/image_hash.dart';

void main() async {
  // Find all similar images in a directory
  final similarGroups = await findSimilarImages(
    '/path/to/images',
    exts: ['.jpg', '.jpeg', '.png'],
    distanceThreshold: 20, // Lower values find more similar images
    onProgress: (progress) {
      print(progress); // Shows real-time progress updates
    },
  );
  
  // Process the similar image groups
  for (int i = 0; i < similarGroups.length; i++) {
    final group = similarGroups[i];
    print('Similar image group ${i + 1} (${group.length} images):');
    for (final (path, hash) in group) {
      print('  $path');
    }
  }
}
```

### Batch Operations

```dart
// Compare one hash against multiple hashes
final targetHash = ImageHasher.perceptual(targetImage);
final hashes = [
  'image1.jpg',
  'image2.jpg',
  'image3.jpg',
].map((img) => ImageHasher.perceptual(img)).toList();

// Get similarity scores for all images
List<double> similarities = ImageHasher.batchCompareSimilarity(targetHash, hashes);

// Get distances for all images
List<int> distances = ImageHasher.batchCompareDistance(targetHash, hashes);

// Find the most similar image
int mostSimilarIndex = similarities.indexOf(similarities.reduce(math.max));
```

### Hash Conversion

```dart
// Convert hash to hex string
final hash = ImageHasher.average(image);
final hexString = hash.toString();  // Format: "average:1a2b3c4d5e6f7890"

// Create hash from hex string
final newHash = ImageHash.fromHex("1a2b3c4d5e6f7890", HashFn.average);

// Create hash from string
final hashFromString = ImageHash.fromString("average:1a2b3c4d5e6f7890");

// Convert to and from bytes
final bytes = hash.toBytes();
final hashFromBytes = ImageHash.fromBytes(bytes, HashFn.average);
```


## API Reference

### Classes

- `ImageHash`: Represents a hash value of an image with methods for comparison
- `ImageHasher`: Static methods to generate different types of image hashes

### Enums

- `HashFn`: Defines the type of hash algorithm (average, perceptual, difference, wavelet, median)
- `HashDirection`: Specifies the direction for the difference hash algorithm (horizontal, vertical, both)

### Utils

- `findSimilarImages`: Function to find groups of similar images in a directory


## License

```
MIT License
```
