import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../data/tones.dart';
import 'editor_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isInitializing = true;
  int _selectedCameraIndex = 0;
  int _selectedToneIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _setupController(_cameras[_selectedCameraIndex]);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _setupController(CameraDescription camera) async {
    setState(() => _isInitializing = true);
    await _controller?.dispose();

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitializing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final nextFlash = _flashMode == FlashMode.off
        ? FlashMode.auto
        : _flashMode == FlashMode.auto
            ? FlashMode.always
            : FlashMode.off;
    try {
      await _controller!.setFlashMode(nextFlash);
      setState(() => _flashMode = nextFlash);
    } catch (_) {}
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);
    try {
      final XFile photo = await _controller!.takePicture();
      final Uint8List bytes = await File(photo.path).readAsBytes();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EditorScreen(
            imagePath: photo.path,
            imageBytes: bytes,
            initialToneIndex: _selectedToneIndex,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Film Viewfinder', style: TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _flashMode == FlashMode.off
                  ? Icons.flash_off_rounded
                  : _flashMode == FlashMode.auto
                      ? Icons.flash_auto_rounded
                      : Icons.flash_on_rounded,
              color: _flashMode == FlashMode.off ? Colors.white54 : const Color(0xFFFFB74D),
            ),
            onPressed: _toggleFlash,
          ),
          if (_cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
              onPressed: _toggleCamera,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Camera Viewfinder Box
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.6), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _isInitializing || _controller == null || !_controller!.value.isInitialized
                            ? const Center(child: CircularProgressIndicator())
                            : CameraPreview(_controller!),
                      ),

                      // Viewfinder Frame Corners & Grid Overlay
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24, width: 1),
                            ),
                          ),
                        ),
                      ),

                      // Active Tone Badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFB74D), width: 1),
                          ),
                          child: Text(
                            kFilmTones[_selectedToneIndex].name.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFFFB74D),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tone Selector Strip
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: kFilmTones.length,
                itemBuilder: (context, index) {
                  final tone = kFilmTones[index];
                  final isSelected = index == _selectedToneIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedToneIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFB74D) : Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tone.name,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Retro Shutter Controls
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _isCapturing ? null : _takePicture,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFFFB74D), width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB74D).withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _isCapturing
                          ? const Center(
                              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black))
                          : Center(
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFFFB74D),
                                ),
                              ),
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
