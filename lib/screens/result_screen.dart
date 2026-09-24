import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:share_plus/share_plus.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  final Uint8List imageBytes;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.imageBytes,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isSaving = false;
  bool _isSaved = false;

  Future<void> _share() async {
    HapticFeedback.selectionClick();
    await Share.shareXFiles([XFile(widget.imagePath)]);
  }

  Future<void> _saveToGallery() async {
    HapticFeedback.heavyImpact();
    setState(() => _isSaving = true);
    try {
      final result = await ImageGallerySaverPlus.saveImage(
        widget.imageBytes,
        quality: 95,
        name: 'utsurikomi_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;

      if (result != null) {
        setState(() => _isSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFFB74D),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.black),
                const SizedBox(width: 8),
                Text(
                  'Saved to Gallery (${(widget.imageBytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1)} MB)',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeMb = (widget.imageBytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('DEVELOPED FILM',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home_rounded, color: Colors.white70),
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Film Roll Badge
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB74D).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFB74D), width: 0.8),
              ),
              child: Text(
                'HIGH RES EXPORT • $sizeMb MB',
                style: const TextStyle(
                  color: Color(0xFFFFB74D),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // Zoomable Result Image Canvas
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Image.memory(
                      widget.imageBytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, __) => Center(
                        child: Text('Error: $error', style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Save to Gallery Button
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveToGallery,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB74D),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.black))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(_isSaved ? Icons.check_circle_rounded : Icons.download_rounded, size: 22),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isSaved ? 'Saved to Gallery' : 'Save to Gallery',
                                        style: const TextStyle(
                                            fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Share Button
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _share,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.share_rounded, size: 18),
                                SizedBox(width: 6),
                                Text('Share',
                                    style: TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Back to Studio / Start Over Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.tune_rounded, size: 16, color: Colors.white70),
                        label: const Text('Back to Edit',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                        icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Colors.white54),
                        label: const Text('New Photo',
                            style: TextStyle(color: Colors.white54, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
