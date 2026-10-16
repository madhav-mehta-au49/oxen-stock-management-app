import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regenerates every launcher / web / iOS icon from one vector drawing.
///
/// Run with:
///   flutter test tool/generate_icons_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate app icons', () async {
    const android = <String, int>{
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
    };

    const web = <String, int>{
      'web/icons/Icon-192.png': 192,
      'web/icons/Icon-512.png': 512,
      'web/favicon.png': 48,
    };

    const webMaskable = <String, int>{
      'web/icons/Icon-maskable-192.png': 192,
      'web/icons/Icon-maskable-512.png': 512,
    };

    const ios = <String, int>{
      'Icon-App-20x20@1x.png': 20,
      'Icon-App-20x20@2x.png': 40,
      'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29,
      'Icon-App-29x29@2x.png': 58,
      'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40,
      'Icon-App-40x40@2x.png': 80,
      'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76,
      'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167,
      'Icon-App-1024x1024@1x.png': 1024,
    };

    const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

    for (final entry in android.entries) {
      await _writeIcon(entry.key, entry.value);
    }
    for (final entry in web.entries) {
      await _writeIcon(entry.key, entry.value);
    }
    for (final entry in webMaskable.entries) {
      await _writeIcon(entry.key, entry.value, contentScale: 0.78);
    }
    for (final entry in ios.entries) {
      await _writeIcon('$iosDir/${entry.key}', entry.value);
    }
  });
}

Future<void> _writeIcon(String path, int size, {double contentScale = 1}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
  );
  _draw(canvas, size.toDouble(), contentScale);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Navy gradient tile with an amber sun: matches `BrandMark` in the app.
void _draw(Canvas canvas, double s, double contentScale) {
  const navyTop = Color(0xFF2C3A52);
  const navyBottom = Color(0xFF141C29);
  const amberLight = Color(0xFFF9C24A);
  const amberDeep = Color(0xFFE07B1F);

  final full = Rect.fromLTWH(0, 0, s, s);
  canvas.drawRect(
    full,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [navyTop, navyBottom],
      ).createShader(full),
  );

  final centre = Offset(s / 2, s / 2);

  // Warm glow behind the sun.
  canvas.drawCircle(
    centre,
    s * 0.46 * contentScale,
    Paint()
      ..shader = RadialGradient(
        colors: [
          amberDeep.withValues(alpha: 0.35),
          amberDeep.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: centre, radius: s * 0.46)),
  );

  // Rays.
  final ray = Paint()
    ..color = amberLight
    ..strokeWidth = s * 0.045 * contentScale
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  for (var i = 0; i < 8; i++) {
    final angle = i * math.pi / 4;
    final dir = Offset(math.cos(angle), math.sin(angle));
    canvas.drawLine(
      centre + dir * (s * 0.225 * contentScale),
      centre + dir * (s * 0.335 * contentScale),
      ray,
    );
  }

  // Disc.
  canvas.drawCircle(
    centre,
    s * 0.165 * contentScale,
    Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [amberLight, amberDeep],
      ).createShader(
        Rect.fromCircle(center: centre, radius: s * 0.165 * contentScale),
      ),
  );

  // Specular highlight for a little depth.
  canvas.drawCircle(
    centre + Offset(-s * 0.05, -s * 0.055) * contentScale,
    s * 0.055 * contentScale,
    Paint()..color = Colors.white.withValues(alpha: 0.28),
  );
}
