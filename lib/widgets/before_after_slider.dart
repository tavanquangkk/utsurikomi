import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BeforeAfterSlider extends StatefulWidget {
  final Uint8List originalBytes;
  final Uint8List editedBytes;

  const BeforeAfterSlider({
    super.key,
    required this.originalBytes,
    required this.editedBytes,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _sliderPosition = 0.5; // 0.0 to 1.0

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return GestureDetector(
          onHorizontalDragStart: (_) {
            HapticFeedback.selectionClick();
          },
          onHorizontalDragUpdate: (details) {
            setState(() {
              _sliderPosition = (details.localPosition.dx / width).clamp(0.0, 1.0);
            });
          },
          child: Stack(
            children: [
              // Bottom Layer: Edited Image
              Positioned.fill(
                child: Image.memory(
                  widget.editedBytes,
                  fit: BoxFit.contain,
                ),
              ),

              // Top Layer: Original Image (Clipped by slider position)
              Positioned.fill(
                child: ClipRect(
                  clipper: _BeforeAfterClipper(_sliderPosition),
                  child: Image.memory(
                    widget.originalBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Glassmorphic Divider Handle Line
              Positioned(
                left: (width * _sliderPosition - 18).clamp(0.0, width - 36),
                top: 0,
                bottom: 0,
                child: Container(
                  width: 36,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Vertical Line
                      Container(
                        width: 2,
                        height: height,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFB74D),
                          boxShadow: [
                            BoxShadow(color: Colors.black87, blurRadius: 6),
                          ],
                        ),
                      ),
                      // Circular Glass Handle
                      ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFFB74D), width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 8),
                              ],
                            ),
                            child: const Icon(
                              Icons.compare_arrows_rounded,
                              color: Color(0xFFFFB74D),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Frosted Glass Badges (ORIGINAL / EDITED)
              Positioned(
                top: 12,
                left: 12,
                child: _buildGlassBadge('ORIGINAL', Colors.black54),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _buildGlassBadge('EDITED', const Color(0xFFFFB74D).withValues(alpha: 0.85)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassBadge(String label, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24, width: 0.8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _BeforeAfterClipper extends CustomClipper<Rect> {
  final double position;

  _BeforeAfterClipper(this.position);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * position, size.height);
  }

  @override
  bool shouldReclip(_BeforeAfterClipper oldClipper) {
    return oldClipper.position != position;
  }
}
