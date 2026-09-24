import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_screen.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final imageBytes = await picked.readAsBytes();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          imagePath: picked.path,
          imageBytes: imageBytes,
          initialToneIndex: 0,
        ),
      ),
    );
  }

  void _openCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Utsurikomi'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('FILM LAB',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFC99A5B),
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      )),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.92, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, scale, child) => Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFC99A5B).withValues(alpha: 0.10),
                      border: Border.all(
                        color: const Color(0xFFC99A5B).withValues(alpha: 0.22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFC99A5B).withValues(alpha: 0.08),
                          blurRadius: 32,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_outlined,
                      size: 58,
                      color: Color(0xFFC99A5B),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _openCamera,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC99A5B),
                        foregroundColor: Colors.black,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded, size: 22),
                          SizedBox(width: 10),
                          Text('Take Film Photo',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _pickImage,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white38),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 20, color: Colors.white70),
                          SizedBox(width: 10),
                          Text('Choose from Gallery',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70)),
                        ],
                      ),
                    ),
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
