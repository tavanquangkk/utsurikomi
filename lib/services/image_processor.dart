import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'cube_lut.dart';

enum GrainLevel {
  off(0, 'No Grain'),
  subtle(8, 'Subtle'),
  classic(16, 'Classic'),
  strong(28, 'Strong');

  const GrainLevel(this.amount, this.label);
  final int amount;
  final String label;
}

enum FrameStyle {
  none('No Frame'),
  white('Classic White'),
  black('Black Border');

  const FrameStyle(this.label);
  final String label;
}

class NoteOptions {
  const NoteOptions({
    this.text = '',
    this.includeDate = false,
    this.fontSize = 24,
    this.color = 0xFF121212,
    this.frameThickness = 3,
  });

  final String text;
  final bool includeDate;
  final int fontSize;
  final int color;
  final int frameThickness;

  bool get enabled => text.trim().isNotEmpty || includeDate;
}

class ImageProcessor {
  static final Map<String, CubeLut> _lutCache = {};

  static Future<({String path, Uint8List bytes})> applyTone({
    required Uint8List sourceBytes,
    required String lutAssetPath,
    required String toneId,
    required GrainLevel grain,
    required FrameStyle frame,
    NoteOptions note = const NoteOptions(),
    bool applyFilter = true,
  }) async {
    final outputBytes = await processBytes(
      sourceBytes: sourceBytes,
      lutAssetPath: lutAssetPath,
      toneId: toneId,
      grain: grain,
      frame: frame,
      note: note,
      applyFilter: applyFilter,
      maxDimension: null,
    );
    final dir = await getTemporaryDirectory();
    final outputFile = await _createOutputFile(dir);
    await outputFile.writeAsBytes(outputBytes, flush: true);
    return (path: outputFile.path, bytes: outputBytes);
  }

  static Future<Uint8List> processBytes({
    required Uint8List sourceBytes,
    required String lutAssetPath,
    required String toneId,
    GrainLevel grain = GrainLevel.off,
    FrameStyle frame = FrameStyle.none,
    NoteOptions note = const NoteOptions(),
    bool applyFilter = true,
    int? maxDimension = 2000,
  }) async {
    if (!applyFilter &&
        grain == GrainLevel.off &&
        frame == FrameStyle.none &&
        !note.enabled) {
      return sourceBytes;
    }

    final lut = applyFilter
        ? (_lutCache[lutAssetPath] ??= await CubeLut.fromAsset(lutAssetPath))
        : null;

    return Isolate.run(
      () => _processInIsolate(
        sourceBytes: sourceBytes,
        lutData: lut?.data ?? Float32List(0),
        lutSize: lut?.size ?? 0,
        applyFilter: applyFilter,
        grainAmount: grain.amount,
        frameIndex: frame.index,
        noteText: note.text.trim(),
        noteDate: note.includeDate ? _formatDate(DateTime.now()) : '',
        noteFontSize: note.fontSize,
        frameThickness: note.frameThickness,
        maxDimension: maxDimension,
      ),
    );
  }

  static Uint8List _processInIsolate({
    required Uint8List sourceBytes,
    required Float32List lutData,
    required int lutSize,
    required bool applyFilter,
    required int grainAmount,
    required int frameIndex,
    required String noteText,
    required String noteDate,
    required int noteFontSize,
    required int frameThickness,
    required int? maxDimension,
  }) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) throw Exception('Unable to read image');

    // Resize large images to keep processing responsive.
    final largestDimension =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final limit = maxDimension;
    final src = limit == null || largestDimension <= limit
        ? decoded
        : (decoded.width >= decoded.height
            ? img.copyResize(decoded, width: limit)
            : img.copyResize(decoded, height: limit));

    final needsPixelPass = applyFilter || grainAmount > 0;
    final out = needsPixelPass ? img.Image.from(src) : src;
    if (needsPixelPass) {
      for (var y = 0; y < out.height; y++) {
        for (var x = 0; x < out.width; x++) {
          final pixel = out.getPixel(x, y);
          var rgb = applyFilter
              ? _lookup(
                  lutData,
                  lutSize,
                  pixel.r.toInt(),
                  pixel.g.toInt(),
                  pixel.b.toInt(),
                )
              : [
                  pixel.r.toInt(),
                  pixel.g.toInt(),
                  pixel.b.toInt(),
                ];
          if (grainAmount > 0) {
            final noise = _noise(x, y);
            rgb = [
              (rgb[0] + noise * grainAmount ~/ 16).clamp(0, 255),
              (rgb[1] + noise * grainAmount ~/ 16).clamp(0, 255),
              (rgb[2] + noise * grainAmount ~/ 16).clamp(0, 255),
            ];
          }
          out.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
        }
      }
    }

    final framed = _addFrame(
      out,
      frameIndex,
      noteText: noteText,
      noteDate: noteDate,
      noteFontSize: noteFontSize,
      frameThickness: frameThickness,
    );
    return Uint8List.fromList(img.encodeJpg(framed, quality: 95));
  }

  static String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  static int _noise(int x, int y) {
    var value = (x * 374761393 + y * 668265263) & 0x7fffffff;
    value = (value ^ (value >> 13)) * 1274126177 & 0x7fffffff;
    return (value % 33) - 16;
  }

  static img.Image _addFrame(
    img.Image image,
    int frameIndex, {
    required String noteText,
    required String noteDate,
    required int noteFontSize,
    required int frameThickness,
  }) {
    if (frameIndex == FrameStyle.none.index &&
        noteText.isEmpty &&
        noteDate.isEmpty) {
      return image;
    }
    final shortestSide =
        image.width < image.height ? image.width : image.height;
    final border = (shortestSide * frameThickness / 100).round().clamp(8, 240);
    final frameColor = frameIndex == FrameStyle.black.index
        ? img.ColorRgb8(18, 18, 18)
        : img.ColorRgb8(248, 246, 240);
    final noteColor = frameIndex == FrameStyle.black.index
        ? img.ColorRgb8(248, 246, 240)
        : img.ColorRgb8(18, 18, 18);
    final note =
        [noteText, noteDate].where((part) => part.isNotEmpty).join('  •  ');
    final textScale = noteFontSize * shortestSide / (720 * 24);
    final sourceFont = note.isEmpty
        ? null
        : noteFontSize <= 16
            ? img.arial14
            : noteFontSize <= 32
                ? img.arial24
                : img.arial48;
    final sourceHeight = sourceFont?.lineHeight ?? 0;
    final textHeight =
        note.isEmpty ? 0 : (sourceHeight * textScale).round().clamp(1, 240);
    final notePadding = (shortestSide * 0.02).round().clamp(8, 48);
    final bottomBorder =
        note.isEmpty ? border : (textHeight + notePadding).clamp(border, 240);
    final framed = img.Image(
      width: image.width + border * 2,
      height: image.height + border + bottomBorder,
      backgroundColor: frameColor,
    );
    framed.clear(frameColor);
    img.compositeImage(framed, image, dstX: border, dstY: border);
    if (note.isNotEmpty) {
      final textLayer = img.Image(
        width: (note.length * sourceHeight + 32).clamp(1, framed.width),
        height: sourceHeight,
        numChannels: 4,
      );
      textLayer.clear(img.ColorRgba8(0, 0, 0, 0));
      img.drawString(
        textLayer,
        note,
        font: sourceFont!,
        x: null,
        y: 0,
        color: noteColor,
      );
      final scaledLayer = img.copyResize(
        textLayer,
        width: (textLayer.width * textScale).round().clamp(1, framed.width),
        height: textHeight,
      );
      img.compositeImage(
        framed,
        scaledLayer,
        dstX: (framed.width - scaledLayer.width) ~/ 2,
        dstY: image.height + border + (bottomBorder - textHeight) ~/ 2,
      );
    }
    return framed;
  }

  static List<int> _lookup(
    Float32List data,
    int size,
    int r,
    int g,
    int b,
  ) {
    final rf = r / 255.0 * (size - 1);
    final gf = g / 255.0 * (size - 1);
    final bf = b / 255.0 * (size - 1);
    final r0 = rf.floor().clamp(0, size - 1);
    final g0 = gf.floor().clamp(0, size - 1);
    final b0 = bf.floor().clamp(0, size - 1);
    final r1 = (r0 + 1).clamp(0, size - 1);
    final g1 = (g0 + 1).clamp(0, size - 1);
    final b1 = (b0 + 1).clamp(0, size - 1);
    final dr = rf - r0;
    final dg = gf - g0;
    final db = bf - b0;

    double sample(int ri, int gi, int bi, int channel) =>
        data[((bi * size + gi) * size + ri) * 3 + channel];

    double interpolate(int channel) {
      final c00 = sample(r0, g0, b0, channel) * (1 - dr) +
          sample(r1, g0, b0, channel) * dr;
      final c10 = sample(r0, g1, b0, channel) * (1 - dr) +
          sample(r1, g1, b0, channel) * dr;
      final c01 = sample(r0, g0, b1, channel) * (1 - dr) +
          sample(r1, g0, b1, channel) * dr;
      final c11 = sample(r0, g1, b1, channel) * (1 - dr) +
          sample(r1, g1, b1, channel) * dr;
      final c0 = c00 * (1 - dg) + c10 * dg;
      final c1 = c01 * (1 - dg) + c11 * dg;
      return (c0 * (1 - db) + c1 * db) * 255;
    }

    return [
      interpolate(0).round().clamp(0, 255),
      interpolate(1).round().clamp(0, 255),
      interpolate(2).round().clamp(0, 255),
    ];
  }

  static Future<File> _createOutputFile(Directory dir) async {
    File outputFile;
    var attempt = 0;
    do {
      final suffix = attempt == 0
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : '${DateTime.now().microsecondsSinceEpoch}_$attempt';
      outputFile = File('${dir.path}/utsurikomi_$suffix.jpg');
      attempt++;
      try {
        await outputFile.create(exclusive: true);
        break;
      } on FileSystemException catch (error) {
        if (error.osError?.errorCode != 17 || attempt > 10) rethrow;
      }
    } while (true);
    return outputFile;
  }
}
