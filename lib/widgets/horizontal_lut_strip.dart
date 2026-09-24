import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/tones.dart';
import '../services/native_image_processor.dart';

class HorizontalLutStrip extends StatefulWidget {
  final Uint8List sourceBytes;
  final int selectedIndex;
  final bool filterEnabled;
  final ValueChanged<int?> onSelectTone;

  const HorizontalLutStrip({
    super.key,
    required this.sourceBytes,
    required this.selectedIndex,
    required this.filterEnabled,
    required this.onSelectTone,
  });

  @override
  State<HorizontalLutStrip> createState() => _HorizontalLutStripState();
}

class _HorizontalLutStripState extends State<HorizontalLutStrip> {
  final Map<String, Uint8List> _thumbCache = {};

  @override
  void initState() {
    super.initState();
    _generateThumbnails();
  }

  @override
  void didUpdateWidget(HorizontalLutStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceBytes != widget.sourceBytes) {
      _thumbCache.clear();
      _generateThumbnails();
    }
  }

  Future<void> _generateThumbnails() async {
    for (int i = 0; i < kFilmTones.length; i++) {
      final tone = kFilmTones[i];
      if (_thumbCache.containsKey(tone.id)) continue;

      try {
        final bytes = await NativeImageProcessor.processBytes(
          sourceBytes: widget.sourceBytes,
          lutAssetPath: tone.lutPath,
          toneId: tone.id,
          applyFilter: true,
          maxDimension: 150,
        );
        if (mounted) {
          setState(() {
            _thumbCache[tone.id] = bytes;
          });
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsCount = kFilmTones.length + 1; // 1 for 'No Filter'

    return SizedBox(
      height: 108,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: itemsCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = !widget.filterEnabled;
            return _buildThumbnailCard(
              title: 'NONE',
              isSelected: isSelected,
              imageBytes: widget.sourceBytes,
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onSelectTone(null);
              },
            );
          }

          final toneIndex = index - 1;
          final tone = kFilmTones[toneIndex];
          final isSelected = widget.filterEnabled && widget.selectedIndex == toneIndex;
          final thumbBytes = _thumbCache[tone.id] ?? widget.sourceBytes;

          return _buildThumbnailCard(
            title: tone.name,
            isSelected: isSelected,
            imageBytes: thumbBytes,
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onSelectTone(toneIndex);
            },
          );
        },
      ),
    );
  }

  Widget _buildThumbnailCard({
    required String title,
    required bool isSelected,
    required Uint8List imageBytes,
    required VoidCallback onTap,
  }) {
    const activeColor = Color(0xFFFFB74D);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            // Image Box with Animated Transform & Border Glow
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: isSelected ? 68 : 62,
              height: isSelected ? 68 : 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? activeColor : Colors.white24,
                  width: isSelected ? 2.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.45),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Title Label
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? activeColor : Colors.white70,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                letterSpacing: isSelected ? 0.5 : 0.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
