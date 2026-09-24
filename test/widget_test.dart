import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:utsurikomi/data/tones.dart';
import 'package:utsurikomi/main.dart';
import 'package:utsurikomi/services/image_processor.dart';

void main() {
  testWidgets('Home displays the photo picker action', (tester) async {
    await tester.pumpWidget(const UtsurikomiApp());
    await tester.pumpAndSettle();

    expect(find.text('Choose from Gallery'), findsOneWidget);
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

  test('Grain and frame options affect the output', () async {
    final source = img.Image(width: 40, height: 30);
    source.clear(img.ColorRgb8(120, 120, 120));
    final sourceBytes = Uint8List.fromList(img.encodeJpg(source));
    final tone = kFilmTones.first;

    final plain = await ImageProcessor.processBytes(
      sourceBytes: sourceBytes,
      lutAssetPath: tone.lutPath,
      toneId: tone.id,
      maxDimension: 64,
    );
    final framed = await ImageProcessor.processBytes(
      sourceBytes: sourceBytes,
      lutAssetPath: tone.lutPath,
      toneId: tone.id,
      grain: GrainLevel.classic,
      frame: FrameStyle.white,
      note: const NoteOptions(
        text: 'Utsurikomi',
        includeDate: true,
        fontSize: 24,
        color: 0xFF121212,
      ),
      maxDimension: 64,
    );

    final plainImage = img.decodeImage(plain)!;
    final framedImage = img.decodeImage(framed)!;
    expect(framedImage.width, greaterThan(plainImage.width));
    expect(framedImage.height, greaterThan(plainImage.height));
    expect(framed, isNot(equals(plain)));
    final corner = framedImage.getPixel(0, 0);
    expect(corner.r, greaterThan(220));
    expect(corner.g, greaterThan(220));
    expect(corner.b, greaterThan(220));

    final blackFramed = await ImageProcessor.processBytes(
      sourceBytes: sourceBytes,
      lutAssetPath: tone.lutPath,
      toneId: tone.id,
      frame: FrameStyle.black,
      maxDimension: 64,
    );
    final blackCorner = img.decodeImage(blackFramed)!.getPixel(0, 0);
    expect(blackCorner.r, lessThan(40));
    expect(blackCorner.g, lessThan(40));
    expect(blackCorner.b, lessThan(40));
  });

  test('No filter preserves source bytes when no effects are selected',
      () async {
    final source = img.Image(width: 12, height: 12);
    source.clear(img.ColorRgb8(90, 120, 150));
    final sourceBytes = Uint8List.fromList(img.encodeJpg(source));

    final output = await ImageProcessor.processBytes(
      sourceBytes: sourceBytes,
      lutAssetPath: kFilmTones.first.lutPath,
      toneId: 'none',
      applyFilter: false,
      maxDimension: null,
    );

    expect(identical(output, sourceBytes), isTrue);
  });
}
