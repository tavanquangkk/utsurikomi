import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../data/tones.dart';
import '../services/image_processor.dart';
import 'result_screen.dart';

class EditorScreen extends StatefulWidget {
  final String imagePath;
  final Uint8List imageBytes;
  final int initialToneIndex;

  const EditorScreen({
    super.key,
    required this.imagePath,
    required this.imageBytes,
    required this.initialToneIndex,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late int _toneIndex;
  Uint8List? _previewBytes;
  bool _showOriginal = false;
  bool _saving = false;
  bool _previewing = false;
  int _previewGeneration = 0;
  final Map<int, Uint8List> _previewCache = {};
  Timer? _previewTimer;

  @override
  void initState() {
    super.initState();
    _toneIndex = widget.initialToneIndex;
    _updatePreview();
  }

  Future<void> _updatePreview() async {
    final generation = ++_previewGeneration;
    final cached = _previewCache[_toneIndex];
    if (cached != null) {
      setState(() {
        _previewBytes = cached;
        _previewing = false;
      });
      return;
    }

    setState(() => _previewing = true);
    try {
      final bytes = await ImageProcessor.processBytes(
        sourceBytes: widget.imageBytes,
        lutAssetPath: kFilmTones[_toneIndex].lutPath,
        toneId: kFilmTones[_toneIndex].id,
        maxDimension: 900,
      );
      if (mounted && generation == _previewGeneration) {
        _previewCache[_toneIndex] = bytes;
        setState(() => _previewBytes = bytes);
      }
    } finally {
      if (mounted && generation == _previewGeneration) {
        setState(() => _previewing = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final output = await ImageProcessor.applyTone(
        sourceBytes: widget.imageBytes,
        lutAssetPath: kFilmTones[_toneIndex].lutPath,
        toneId: kFilmTones[_toneIndex].id,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            imagePath: output.path,
            imageBytes: output.bytes,
          ),
        ),
        (route) => route.isFirst, // Keep Home and remove Editor.
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Apply',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _showOriginal
                    ? Image.memory(widget.imageBytes, fit: BoxFit.contain)
                    : _previewing || _previewBytes == null
                        ? const CircularProgressIndicator()
                        : Image.memory(_previewBytes!, fit: BoxFit.contain),
              ),
            ),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kFilmTones.length,
                itemBuilder: (_, i) {
                  final selected = _toneIndex == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _toneIndex = i);
                      _previewTimer?.cancel();
                      _previewTimer = Timer(
                        const Duration(milliseconds: 120),
                        _updatePreview,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        kFilmTones[i].name,
                        style: TextStyle(
                          color: selected ? Colors.black : Colors.white,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Listener(
                onPointerDown: (_) => setState(() => _showOriginal = true),
                onPointerUp: (_) => setState(() => _showOriginal = false),
                onPointerCancel: (_) => setState(() => _showOriginal = false),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white38),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Hold to view original',
                      style: TextStyle(color: Colors.white70)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }
}
