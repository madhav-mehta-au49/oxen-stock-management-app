import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A compressed pair for one product photo.
class CompressedImage {
  const CompressedImage({required this.thumb, required this.full});
  final Uint8List thumb;
  final Uint8List full;
}

/// On-device image compression (no server / no Firebase Storage).
class ImageService {
  const ImageService._();

  /// Produces a small thumbnail (for lists) and a larger full image
  /// (for the detail screen) from raw picked bytes.
  static Future<CompressedImage> compress(Uint8List input) =>
      compute(_compress, input);

  static CompressedImage _compress(Uint8List input) {
    final decoded = img.decodeImage(input);
    if (decoded == null) {
      throw const FormatException('Unsupported image format');
    }
    return CompressedImage(
      thumb: _encode(decoded, 240, 60),
      full: _encode(decoded, 900, 72),
    );
  }

  static Uint8List _encode(img.Image source, int maxSide, int quality) {
    final w = source.width;
    final h = source.height;
    final longest = w > h ? w : h;
    var out = source;
    if (longest > maxSide) {
      out = w >= h
          ? img.copyResize(
              source,
              width: maxSide,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              source,
              height: maxSide,
              interpolation: img.Interpolation.average,
            );
    }
    return Uint8List.fromList(img.encodeJpg(out, quality: quality));
  }
}
