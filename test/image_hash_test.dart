import 'dart:io';

import 'package:image/image.dart';
import 'package:image_hash/image_hash.dart';
import 'package:test/test.dart';

const _testDir = 'test/fixtures/';

void main() {
  group('Perceptual Hash', () {
    test('compressed', () {
      final exp1 = _perceptualHash('origin.png', 'compressed.jpg');
      expect(exp1, completion(0));
    });

    test('compressed and edited', () {
      final exp1 = _perceptualHash('origin.png', 'edited.jpg');
      expect(exp1, completion(greaterThan(10)));

      final exp2 = _perceptualHash('origin.png', 'edited2.jpg');
      expect(exp2, completion(greaterThan(10)));
    });

    test('transformed', () {
      final exp1 = _perceptualHash('origin.png', 'transformed.jpg');
      expect(exp1, completion(greaterThan(30)));
    });
  });

  group('Average Hash', () {
    test('compressed', () {
      final exp1 = _averageHash('origin.png', 'compressed.jpg');
      expect(exp1, completion(lessThan(10)));
    });

    test('compressed and edited', () {
      final exp1 = _averageHash('origin.png', 'edited.jpg');
      expect(exp1, completion(greaterThan(0)));
    });
  });

  group('Difference Hash', () {
    // test('compressed', () {
    //   final exp1 = _differenceHash('origin.png', 'compressed.jpg');
    //   expect(exp1, completion(lessThan(15)));
    // });

    test('horizontal direction', () {
      final exp1 = _differenceHash('origin.png', 'edited.jpg',
          direction: HashDirection.horizontal);
      expect(exp1, completion(greaterThan(0)));
    });

    test('vertical direction', () {
      final exp1 = _differenceHash('origin.png', 'edited.jpg',
          direction: HashDirection.vertical);
      expect(exp1, completion(greaterThan(0)));
    });
  });

  group('Wavelet Hash', () {
    test('compressed', () {
      final exp1 = _waveletHash('origin.png', 'compressed.jpg');
      expect(exp1, completion(lessThan(15)));
    });

    test('edited image', () {
      final exp1 = _waveletHash('origin.png', 'edited.jpg');
      expect(exp1, completion(greaterThan(0)));
    });
  });

  group('Median Hash', () {
    test('compressed', () {
      final exp1 = _medianHash('origin.png', 'compressed.jpg');
      expect(exp1, completion(lessThan(15)));
    });

    test('edited image', () {
      final exp1 = _medianHash('origin.png', 'edited.jpg');
      expect(exp1, completion(greaterThan(0)));
    });
  });

  group('ImageHash class', () {
    test('fromHex and toHex', () async {
      final img =
          decodeImage(await File('${_testDir}origin.png').readAsBytes());
      expect(img, isNotNull);

      final hash = ImageHasher.perceptual(img!);
      final fromHex = ImageHash.fromString(hash.toString());

      expect(hash.distance(fromHex), equals(0));
    });

    test('fromBytes and toBytes', () async {
      final img =
          decodeImage(await File('${_testDir}origin.png').readAsBytes());
      expect(img, isNotNull);

      final hash = ImageHasher.perceptual(img!);
      final bytes = hash.toBytes();
      final fromBytes = ImageHash.fromBytes(bytes, HashFn.perceptual);

      expect(hash.distance(fromBytes), equals(0));
    });

    test('similarity and isSimilar', () async {
      final img1 =
          decodeImage(await File('${_testDir}origin.png').readAsBytes());
      final img2 =
          decodeImage(await File('${_testDir}compressed.jpg').readAsBytes());
      final img3 =
          decodeImage(await File('${_testDir}transformed.jpg').readAsBytes());

      expect(img1, isNotNull);
      expect(img2, isNotNull);
      expect(img3, isNotNull);

      final hash1 = ImageHasher.perceptual(img1!);
      final hash2 = ImageHasher.perceptual(img2!);
      final hash3 = ImageHasher.perceptual(img3!);

      expect(hash1.similarity(hash2), greaterThanOrEqualTo(0.9));
      expect(hash1.isSimilar(hash2), isTrue);

      expect(hash1.similarity(hash3), lessThan(0.9));
      expect(hash1.isSimilar(hash3), isFalse);
    });
  });

  group('Batch operations', () {
    test('batchCompareSimilarity', () async {
      final img1 =
          decodeImage(await File('${_testDir}origin.png').readAsBytes());
      final img2 =
          decodeImage(await File('${_testDir}compressed.jpg').readAsBytes());
      final img3 =
          decodeImage(await File('${_testDir}edited.jpg').readAsBytes());

      expect(img1, isNotNull);
      expect(img2, isNotNull);
      expect(img3, isNotNull);

      final targetHash = ImageHasher.perceptual(img1!);
      final hashes = [
        ImageHasher.perceptual(img2!),
        ImageHasher.perceptual(img3!)
      ];

      final similarities =
          ImageHasher.batchCompareSimilarity(targetHash, hashes);
      expect(similarities.length, equals(2));
      expect(similarities[0],
          greaterThanOrEqualTo(0.9)); // compressed should be very similar
      expect(similarities[1], lessThan(0.9)); // edited should be less similar
    });

    test('batchCompareDistance', () async {
      final img1 =
          decodeImage(await File('${_testDir}origin.png').readAsBytes());
      final img2 =
          decodeImage(await File('${_testDir}compressed.jpg').readAsBytes());
      final img3 =
          decodeImage(await File('${_testDir}edited.jpg').readAsBytes());

      expect(img1, isNotNull);
      expect(img2, isNotNull);
      expect(img3, isNotNull);

      final targetHash = ImageHasher.perceptual(img1!);
      final hashes = [
        ImageHasher.perceptual(img2!),
        ImageHasher.perceptual(img3!)
      ];

      final distances = ImageHasher.batchCompareDistance(targetHash, hashes);
      expect(distances.length, equals(2));
      expect(distances[0], equals(0)); // compressed should have zero distance
      expect(
          distances[1], greaterThan(0)); // edited should have non-zero distance
    });
  });
}

Future<int> _perceptualHash(
  String origin,
  String target,
) async {
  final img1 = decodeImage(await File(_testDir + origin).readAsBytes());
  final img2 = decodeImage(await File(_testDir + target).readAsBytes());

  if (img1 == null || img2 == null) {
    return throw Exception('Load failed');
  }

  final hash1 = ImageHasher.perceptual(img1, size: 64);
  final hash2 = ImageHasher.perceptual(img2, size: 64);

  final distance = hash1.distance(hash2);
  print('Perceptual\n $origin: $hash1 || $target: $hash2 || $distance');

  return distance;
}

Future<int> _averageHash(
  String origin,
  String target,
) async {
  final img1 = decodeImage(await File(_testDir + origin).readAsBytes());
  final img2 = decodeImage(await File(_testDir + target).readAsBytes());

  if (img1 == null || img2 == null) {
    return throw Exception('Load failed');
  }

  final hash1 = ImageHasher.average(img1);
  final hash2 = ImageHasher.average(img2);

  final distance = hash1.distance(hash2);
  print('Average\n $origin: $hash1 || $target: $hash2 || $distance');

  return distance;
}

Future<int> _differenceHash(
  String origin,
  String target, {
  HashDirection direction = HashDirection.both,
}) async {
  final img1 = decodeImage(await File(_testDir + origin).readAsBytes());
  final img2 = decodeImage(await File(_testDir + target).readAsBytes());

  if (img1 == null || img2 == null) {
    return throw Exception('Load failed');
  }

  final hash1 = ImageHasher.difference(img1, direction: direction);
  final hash2 = ImageHasher.difference(img2, direction: direction);

  final distance = hash1.distance(hash2);
  print(
      'Diff(${direction.name})\n $origin: $hash1 || $target: $hash2 || $distance');

  return distance;
}

Future<int> _waveletHash(
  String origin,
  String target,
) async {
  final img1 = decodeImage(await File(_testDir + origin).readAsBytes());
  final img2 = decodeImage(await File(_testDir + target).readAsBytes());

  if (img1 == null || img2 == null) {
    return throw Exception('Load failed');
  }

  final hash1 = ImageHasher.wavelet(img1);
  final hash2 = ImageHasher.wavelet(img2);

  final distance = hash1.distance(hash2);
  print('Wavelet\n $origin: $hash1 || $target: $hash2 || $distance');

  return distance;
}

Future<int> _medianHash(
  String origin,
  String target,
) async {
  final img1 = decodeImage(await File(_testDir + origin).readAsBytes());
  final img2 = decodeImage(await File(_testDir + target).readAsBytes());

  if (img1 == null || img2 == null) {
    return throw Exception('Load failed');
  }

  final hash1 = ImageHasher.median(img1);
  final hash2 = ImageHasher.median(img2);

  final distance = hash1.distance(hash2);
  print('Median\n $origin: $hash1 || $target: $hash2 || $distance');

  return distance;
}
