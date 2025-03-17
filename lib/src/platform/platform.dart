/// Platform-specific implementation selector
library;

export 'package:image_hash/src/platform/io.dart'
    if (dart.library.html) 'package:image_hash/src/platform/web.dart';
