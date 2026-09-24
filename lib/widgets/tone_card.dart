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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(tone.assetPath,
                    fit: BoxFit.cover, width: double.infinity),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tone.name,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
