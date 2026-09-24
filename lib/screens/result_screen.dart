import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:share_plus/share_plus.dart';

class ResultScreen extends StatelessWidget {
  final String imagePath;
  final Uint8List imageBytes;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.imageBytes,
  });

  Future<void> _share() async {
    await Share.shareXFiles([XFile(imagePath)]);
  }

  Future<void> _saveToGallery(BuildContext context) async {
    try {
      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        quality: 95,
        name: 'utsurikomi_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!context.mounted) return;

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Saved to Gallery')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF211E1A),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.memory(
                    imageBytes,
                    key: ValueKey(imagePath),
                    fit: BoxFit.contain,
                    gaplessPlayback: false,
                    errorBuilder: (_, error, __) {
                      return Center(
                        child: Text('Error: $error',
                            style: const TextStyle(color: Colors.white)),
                      );
                    },
                  )),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('✅ Processing complete',
                  style: TextStyle(color: Colors.white70)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _saveToGallery(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF2E8D5),
                        side: const BorderSide(color: Color(0xFF806C51)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save to Gallery'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _share,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Start Over',
                    style: TextStyle(color: Colors.white70)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
