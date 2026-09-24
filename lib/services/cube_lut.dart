import 'dart:typed_data';
import 'package:flutter/services.dart';

class CubeLut {
  final int size;
  final Float32List data; // RGB float, length = size^3 * 3

  CubeLut._(this.size, this.data);

  /// Reads a .cube file from assets.
  static Future<CubeLut> fromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return CubeLut._parse(raw);
  }

  static CubeLut _parse(String content) {
    final lines = content.split('\n');
    int size = 0;
    final values = <double>[];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('TITLE')) continue;

      if (line.startsWith('LUT_3D_SIZE')) {
        size = int.parse(line.split(RegExp(r'\s+'))[1]);
        continue;
      }
      if (line.startsWith('DOMAIN_MIN') || line.startsWith('DOMAIN_MAX')) {
        continue;
      }

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length == 3) {
        values.add(double.parse(parts[0]));
        values.add(double.parse(parts[1]));
        values.add(double.parse(parts[2]));
      }
    }

    if (size == 0 || values.length != size * size * size * 3) {
      throw Exception('Invalid .cube file');
    }

    return CubeLut._(size, Float32List.fromList(values));
  }

  /// Looks up a color with trilinear interpolation.
  List<int> lookup(int r, int g, int b) {
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

    double sample(int ri, int gi, int bi, int channel) {
      final idx = ((bi * size + gi) * size + ri) * 3 + channel;
      return data[idx];
    }

    double interp(int channel) {
      final c000 = sample(r0, g0, b0, channel);
      final c100 = sample(r1, g0, b0, channel);
      final c010 = sample(r0, g1, b0, channel);
      final c110 = sample(r1, g1, b0, channel);
      final c001 = sample(r0, g0, b1, channel);
      final c101 = sample(r1, g0, b1, channel);
      final c011 = sample(r0, g1, b1, channel);
      final c111 = sample(r1, g1, b1, channel);

      final c00 = c000 * (1 - dr) + c100 * dr;
      final c10 = c010 * (1 - dr) + c110 * dr;
      final c01 = c001 * (1 - dr) + c101 * dr;
      final c11 = c011 * (1 - dr) + c111 * dr;

      final c0 = c00 * (1 - dg) + c10 * dg;
      final c1 = c01 * (1 - dg) + c11 * dg;

      return c0 * (1 - db) + c1 * db;
    }

    return [
      (interp(0) * 255).round().clamp(0, 255),
      (interp(1) * 255).round().clamp(0, 255),
      (interp(2) * 255).round().clamp(0, 255),
    ];
  }
}
