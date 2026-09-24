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
  late bool _filterEnabled;
  Uint8List? _previewBytes;
  bool _showOriginal = false;
  bool _saving = false;
  bool _previewing = false;
  int _previewGeneration = 0;
  GrainLevel _grain = GrainLevel.off;
  FrameStyle _frame = FrameStyle.none;
  NoteOptions _note = const NoteOptions();
  late final TextEditingController _noteTextController;
  final Map<String, Uint8List> _previewCache = {};
  Timer? _previewTimer;

  @override
  void initState() {
    super.initState();
    _toneIndex = widget.initialToneIndex;
    _filterEnabled = false;
    _noteTextController = TextEditingController();
    _updatePreview();
  }

  Future<void> _updatePreview() async {
    final generation = ++_previewGeneration;
    final toneIndex = _toneIndex;
    final grain = _grain;
    final frame = _frame;
    final note = _note;
    final noteKey =
        '${note.text}:${note.includeDate}:${note.fontSize}:${note.frameThickness}';
    final cacheKey =
        '$_filterEnabled:$toneIndex:${grain.index}:${frame.index}:$noteKey';
    final cached = _previewCache[cacheKey];
    if (cached != null) {
      setState(() {
        _previewBytes = cached;
        _previewing = false;
      });
      return;
    }

    setState(() => _previewing = true);
    try {
      if (!_filterEnabled &&
          grain == GrainLevel.off &&
          frame == FrameStyle.none &&
          !note.enabled) {
        if (mounted && generation == _previewGeneration) {
          _previewCache[cacheKey] = widget.imageBytes;
          setState(() {
            _previewBytes = widget.imageBytes;
            _previewing = false;
          });
        }
        return;
      }
      final bytes = await ImageProcessor.processBytes(
        sourceBytes: widget.imageBytes,
        lutAssetPath: kFilmTones.first.lutPath,
        toneId: _filterEnabled ? kFilmTones[toneIndex].id : 'none',
        grain: grain,
        frame: frame,
        note: note,
        applyFilter: _filterEnabled,
        maxDimension: 720,
      );
      if (mounted && generation == _previewGeneration) {
        _previewCache[cacheKey] = bytes;
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
        lutAssetPath: kFilmTones.first.lutPath,
        toneId: _filterEnabled ? kFilmTones[_toneIndex].id : 'none',
        grain: _grain,
        frame: _frame,
        note: _note,
        applyFilter: _filterEnabled,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            imagePath: output.path,
            imageBytes: output.bytes,
          ),
        ),
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
            _buildOptions(),
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

  Widget _buildOptions() {
    return SizedBox(
      height: 320,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _buildSection(
            title: 'Filter',
            icon: Icons.auto_awesome,
            summary: _filterEnabled ? kFilmTones[_toneIndex].name : 'No Filter',
            child: _buildChoices(
              values: <String>[
                'No Filter',
                ...kFilmTones.map((tone) => tone.name),
              ],
              selected:
                  _filterEnabled ? kFilmTones[_toneIndex].name : 'No Filter',
              label: (value) => value,
              onSelected: (value) {
                setState(() {
                  if (value == 'No Filter') {
                    _filterEnabled = false;
                  } else {
                    _filterEnabled = true;
                    _toneIndex =
                        kFilmTones.indexWhere((tone) => tone.name == value);
                  }
                });
                _schedulePreview();
              },
            ),
          ),
          _buildSection(
            title: 'Grain',
            icon: Icons.grain,
            summary: _grain.label,
            child: _buildChoices(
              values: GrainLevel.values,
              selected: _grain,
              label: (value) => value.label,
              onSelected: (value) {
                setState(() => _grain = value);
                _schedulePreview();
              },
            ),
          ),
          _buildSection(
            title: 'Frame & Note',
            icon: Icons.crop_square,
            summary:
                '${_frame.label} · ${_frame == FrameStyle.none ? 'No Note' : (_note.enabled ? 'Note On' : 'No Note')}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChoices(
                  values: FrameStyle.values,
                  selected: _frame,
                  label: (value) => value.label,
                  onSelected: (value) {
                    setState(() => _frame = value);
                    _schedulePreview();
                  },
                ),
                if (_frame != FrameStyle.none) ...[
                  const SizedBox(height: 8),
                  _buildNoteControls(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required String summary,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.white10,
        ),
        child: ExpansionTile(
          leading: Icon(icon, color: Colors.white70),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(summary,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 10),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildChoices<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: values
          .map((value) => ChoiceChip(
                label: Text(label(value)),
                selected: value == selected,
                onSelected: (_) => onSelected(value),
              ))
          .toList(),
    );
  }

  Widget _buildNoteControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _noteTextController,
          maxLength: 32,
          decoration: const InputDecoration(
            labelText: 'Note text (optional)',
            hintText: 'e.g. Utsurikomi',
            isDense: true,
          ),
          onChanged: (value) {
            setState(() => _note = NoteOptions(
                  text: value,
                  includeDate: _note.includeDate,
                  fontSize: _note.fontSize,
                  color: _note.color,
                  frameThickness: _note.frameThickness,
                ));
            _schedulePreview();
          },
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Add today\'s date'),
          value: _note.includeDate,
          onChanged: (value) {
            setState(() => _note = NoteOptions(
                  text: _note.text,
                  includeDate: value ?? false,
                  fontSize: _note.fontSize,
                  color: _note.color,
                  frameThickness: _note.frameThickness,
                ));
            _schedulePreview();
          },
        ),
        _buildSlider(
          label: 'Text size',
          value: _note.fontSize.toDouble(),
          min: 14,
          max: 48,
          divisions: 2,
          valueLabel: '${_note.fontSize}',
          onChanged: (value) {
            setState(() => _note = NoteOptions(
                  text: _note.text,
                  includeDate: _note.includeDate,
                  fontSize: value.round(),
                  color: _note.color,
                  frameThickness: _note.frameThickness,
                ));
            _schedulePreview();
          },
        ),
        _buildSlider(
          label: 'Frame thickness',
          value: _note.frameThickness.toDouble(),
          min: 2,
          max: 10,
          divisions: 8,
          valueLabel: '${_note.frameThickness}%',
          onChanged: (value) {
            setState(() => _note = NoteOptions(
                  text: _note.text,
                  includeDate: _note.includeDate,
                  fontSize: _note.fontSize,
                  color: _note.color,
                  frameThickness: value.round(),
                ));
            _schedulePreview();
          },
        ),
        Text(
          _frame == FrameStyle.black
              ? 'Text color: White (automatic)'
              : 'Text color: Black (automatic)',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: value,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(valueLabel, textAlign: TextAlign.end),
        ),
      ],
    );
  }

  void _schedulePreview() {
    _previewTimer?.cancel();
    _previewTimer = Timer(
      const Duration(milliseconds: 120),
      _updatePreview,
    );
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _noteTextController.dispose();
    super.dispose();
  }
}
