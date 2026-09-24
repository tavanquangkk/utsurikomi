import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:utsurikomi/data/tones.dart';
import 'package:utsurikomi/main.dart';
import 'package:utsurikomi/services/image_processor.dart';

void main() {
  testWidgets('Home displays all available filters', (tester) async {
    await tester.pumpWidget(const UtsurikomiApp());
    await tester.pumpAndSettle();

    for (final tone in kFilmTones) {
      await tester.scrollUntilVisible(
        find.text(tone.name),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(tone.name), findsOneWidget);
    }
    expect(find.text('Chọn ảnh từ thư viện'), findsOneWidget);
  });

  test('Each LUT produces an output image', () async {
    final source = img.Image(width: 8, height: 8);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgb(x, y, x * 32, y * 32, 128);
      }
    }
    final sourceBytes = Uint8List.fromList(img.encodeJpg(source));

    for (final tone in kFilmTones) {
      final output = await ImageProcessor.processBytes(
        sourceBytes: sourceBytes,
        lutAssetPath: tone.lutPath,
        toneId: tone.id,
        maxDimension: 64,
      );

      expect(output, isNotEmpty, reason: tone.name);
      expect(img.decodeImage(output), isNotNull, reason: tone.name);
    }
  });
}
