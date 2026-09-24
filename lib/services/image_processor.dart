import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'cube_lut.dart';

class ImageProcessor {
  static final Map<String, CubeLut> _lutCache = {};

  static Future<({String path, Uint8List bytes})> applyTone({
    required Uint8List sourceBytes,
    required String lutAssetPath,
    required String toneId,
  }) async {
    final outputBytes = await processBytes(
      sourceBytes: sourceBytes,
      lutAssetPath: lutAssetPath,
      toneId: toneId,
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
    int maxDimension = 2000,
  }) async {
    final lut =
        _lutCache[lutAssetPath] ??= await CubeLut.fromAsset(lutAssetPath);

    return Isolate.run(
      () => _processInIsolate(
        sourceBytes: sourceBytes,
        lutData: lut.data,
        lutSize: lut.size,
        toneId: toneId,
        maxDimension: maxDimension,
      ),
    );
  }

  static Uint8List _processInIsolate({
    required Uint8List sourceBytes,
    required Float32List? lutData,
    required int? lutSize,
    required String toneId,
    required int maxDimension,
  }) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) throw Exception('Không đọc được ảnh');

    // Resize nếu ảnh quá lớn (tránh lag)
    final largestDimension =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final src = largestDimension > maxDimension
        ? (decoded.width >= decoded.height
            ? img.copyResize(decoded, width: maxDimension)
            : img.copyResize(decoded, height: maxDimension))
        : decoded;

    final out = img.Image.from(src);
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final pixel = out.getPixel(x, y);
        final rgb = _lookup(
          lutData!,
          lutSize!,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
        );
        out.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
      }
    }

    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
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
