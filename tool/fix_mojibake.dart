import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Reverses accidental double-encoding (UTF-8 bytes that were re-decoded as
/// Windows-1252) inside Dart string literals.
///
/// Usage:
///   dart run tool/fix_mojibake.dart           # dry run, prints findings
///   dart run tool/fix_mojibake.dart --apply   # rewrite the files
void main(List<String> args) {
  final apply = args.contains('--apply');
  final files = _dartFiles(Directory('lib')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  var total = 0;

  for (final file in files) {
    final source = file.readAsStringSync();
    final fixed = _fix(source);
    if (fixed == source) continue;

    final count = _runCount(source);
    total += count;
    stdout.writeln('${file.path}: $count sequence(s)');
    _printDiffs(source, fixed);

    if (apply) {
      file.writeAsStringSync(fixed, flush: true);
    }
  }

  stdout.writeln(apply
      ? '\nApplied $total fix(es).'
      : '\nDry run - $total sequence(s) found. Re-run with --apply to write.');
}

Iterable<File> _dartFiles(Directory dir) sync* {
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

/// Code points that only appear in Windows-1252 mojibake, never in normal UI copy.
const _leadChars = {0xE2, 0xE3, 0xC3, 0xC0, 0xC2, 0xC1, 0xE0, 0xE1, 0xE4};

bool _isExtension(int rune) {
  if (rune >= 0x80 && rune <= 0xFF) return true;
  if (rune >= 0x80 && rune <= 0x9F) return true;
  const specials = <int>{
    0x0152, 0x0153, 0x0160, 0x0161, 0x0178, 0x017D, 0x017E, 0x0192,
    0x02C6, 0x02DC,
    0x2013, 0x2014, 0x2018, 0x2019, 0x201A, 0x201C, 0x201D, 0x201E,
    0x2020, 0x2021, 0x2022, 0x2026, 0x2030, 0x2039, 0x203A, 0x203E,
    0x2044, 0x20AC, 0x2122,
  };
  return specials.contains(rune);
}

String _fix(String source) {
  final runes = source.runes.toList();
  final out = <int>[];
  var i = 0;

  while (i < runes.length) {
    if (_leadChars.contains(runes[i]) && i + 1 < runes.length && _isExtension(runes[i + 1])) {
      var j = i + 1;
      while (j < runes.length && _isExtension(runes[j])) {
        j++;
      }
      final run = runes.sublist(i, j);
      final converted = _decodeWindows1252(run);
      if (converted != null && _looksFixed(converted)) {
        out.addAll(converted.runes);
        i = j;
        continue;
      }
    }
    out.add(runes[i]);
    i++;
  }

  return String.fromCharCodes(out);
}

bool _looksFixed(String value) {
  if (value.isEmpty) return false;
  if (_badSequences.hasMatch(value)) return false;
  return value.runes.every((r) => r == 0x09 || r == 0x0A || r >= 0x20);
}

final _badSequences = RegExp('[\u00E2\u00E3\u00C3\u00C0\u00C1][\u0080-\u00FF\u2013\u2014\u2018\u2019\u201A\u201C\u201D\u201E\u2020\u2021\u2022\u2026\u2030\u2039\u203A\u20AC\u2122]');

/// cp1252 byte -> code point for 0x80..0x9F (the rest are identity).
const _cp1252High = <int, int>{
  0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026,
  0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160,
  0x8B: 0x2039, 0x8C: 0x0152, 0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019,
  0x93: 0x201C, 0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
  0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A, 0x9C: 0x0153,
  0x9E: 0x017E, 0x9F: 0x0178,
};

String? _decodeWindows1252(List<int> runes) {
  final bytes = Uint8List(runes.length);
  for (var i = 0; i < runes.length; i++) {
    final r = runes[i];
    var byte = r;
    if (r > 0xFF) {
      final match = _cp1252High.entries.where((e) => e.value == r);
      if (match.isEmpty) return null;
      byte = match.first.key;
    }
    if (byte > 0xFF) return null;
    bytes[i] = byte;
  }
  try {
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    return null;
  }
}

int _runCount(String source) => _badSequences.allMatches(source).length;

void _printDiffs(String before, String after) {
  final a = before.split('\n');
  final b = after.split('\n');
  for (var i = 0; i < a.length && i < b.length; i++) {
    if (a[i] == b[i]) continue;
    stdout.writeln('  ${i + 1}: ${_esc(a[i].trim())}');
    stdout.writeln('   -> ${_esc(b[i].trim())}');
  }
}

String _esc(String value) => value
    .replaceAll('\u2022', '*')
    .replaceAll('\u2192', '->')
    .replaceAll('\u20B9', 'INR')
    .replaceAll('\u2014', '--')
    .replaceAll('\u2026', '...');
