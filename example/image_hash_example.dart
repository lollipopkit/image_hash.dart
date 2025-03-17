import 'dart:io';

import 'package:image/image.dart';
import 'package:image_hash/src/compute.dart';
import 'package:image_hash/src/enums.dart';

void main() async {
  final img1 = decodeImage(await File('sample1.jpg').readAsBytes());
  final img2 = decodeImage(await File('sample2.jpg').readAsBytes());

  if (img1 == null || img2 == null) {
    print('Load failed');
    return;
  }
  
  // Use perceptual hash to compare images
  final hash1 = HashFn.perceptual.hashImg(img1);
  // Same as above
  final hash2 = ImageHasher.perceptualHash(img2);
  
  // 0 means the same image, higher value means more different
  // You must use the same hash function to compare images
  final distance = hash1.distance(hash2);

  print('Hash1: $hash1, Hash2: $hash2, Distance: $distance');
}
