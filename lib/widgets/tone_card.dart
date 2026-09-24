import 'package:flutter/material.dart';
import '../models/film_tone.dart';

class ToneCard extends StatelessWidget {
  final FilmTone tone;
  final bool selected;
  final VoidCallback onTap;

  const ToneCard({
    super.key,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1 : 0.97,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        selected ? const Color(0xFFC99A5B) : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: selected ? 0.3 : 0.18),
                      blurRadius: selected ? 14 : 8,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(tone.assetPath,
                      fit: BoxFit.cover, width: double.infinity),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tone.name,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFF2E8D5)
                    : const Color(0xFFB8AD9B),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
