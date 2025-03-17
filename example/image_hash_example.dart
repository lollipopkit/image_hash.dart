import 'package:image_hash/src/enums.dart';

void main() async {
  // Use perceptual hash to compare images
  final hash1 = await HashFn.perceptual.hashFile('test/fixtures/origin.png');
  final hash2 = await HashFn.perceptual.hashFile('test/fixtures/edited2.jpg');

  // 0 means the same image, higher value means more different.
  // You must use the same hash function to compare images
  final distance = hash1.distance(hash2);
  final similarity = hash1.similarity(hash2);

  print('$hash1 <=> $hash2, Distance: $distance, Similarity: $similarity');
}
