import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/tones.dart';
import '../services/image_processor.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/horizontal_lut_strip.dart';
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
  bool _isCompareMode = false;
  bool _isToolsCollapsed = false;
  bool _saving = false;
  bool _previewing = false;
  int _previewGeneration = 0;
  GrainLevel _grain = GrainLevel.off;
  FrameStyle _frame = FrameStyle.none;
  NoteOptions _note = const NoteOptions();

  // Image Adjustments
  double _exposure = 0.0;  // -1.0 to 1.0
  double _contrast = 0.0;  // -1.0 to 1.0
  double _warmth = 0.0;    // -1.0 to 1.0
  double _vignette = 0.0;  // 0.0 to 1.0

  late final TextEditingController _noteTextController;
  final Map<String, Uint8List> _previewCache = {};
  Timer? _previewTimer;

  bool get _hasActiveAdjustments =>
      _exposure != 0.0 || _contrast != 0.0 || _warmth != 0.0 || _vignette > 0.0;

  bool get _hasActiveGrain => _grain != GrainLevel.off;

  bool get _hasActiveFrame => _frame != FrameStyle.none || _note.enabled;

  @override
  void initState() {
    super.initState();
    _toneIndex = widget.initialToneIndex;
    _filterEnabled = true;
    _noteTextController = TextEditingController();
    _updatePreview();
  }

  void _resetAllEdits() {
    HapticFeedback.mediumImpact();
    setState(() {
      _exposure = 0.0;
      _contrast = 0.0;
      _warmth = 0.0;
      _vignette = 0.0;
      _grain = GrainLevel.off;
      _frame = FrameStyle.none;
      _note = const NoteOptions();
      _noteTextController.clear();
      _filterEnabled = true;
      _toneIndex = 0;
    });
    _schedulePreview();
  }

  Future<void> _updatePreview() async {
    final generation = ++_previewGeneration;
    final toneIndex = _toneIndex;
    final grain = _grain;
    final frame = _frame;
    final note = _note;
    final exp = _exposure;
    final con = _contrast;
    final wrm = _warmth;
    final vig = _vignette;

    final noteKey =
        '${note.text}:${note.includeDate}:${note.fontSize}:${note.frameThickness}';
    final cacheKey =
        '$_filterEnabled:$toneIndex:${grain.index}:${frame.index}:$noteKey:$exp:$con:$wrm:$vig';
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
      final bool hasAdjustments =
          exp != 0.0 || con != 0.0 || wrm != 0.0 || vig > 0.0;

      if (!_filterEnabled &&
          grain == GrainLevel.off &&
          frame == FrameStyle.none &&
          !note.enabled &&
          !hasAdjustments) {
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
        lutAssetPath: kFilmTones[_toneIndex].lutPath,
        toneId: _filterEnabled ? kFilmTones[toneIndex].id : 'none',
        grain: grain,
        frame: frame,
        note: note,
        applyFilter: _filterEnabled,
        exposure: exp,
        contrast: con,
        warmth: wrm,
        vignette: vig,
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
    HapticFeedback.heavyImpact();
    setState(() => _saving = true);
    try {
      final output = await ImageProcessor.applyTone(
        sourceBytes: widget.imageBytes,
        lutAssetPath: kFilmTones[_toneIndex].lutPath,
        toneId: _filterEnabled ? kFilmTones[_toneIndex].id : 'none',
        grain: _grain,
        frame: _frame,
        note: _note,
        applyFilter: _filterEnabled,
        exposure: _exposure,
        contrast: _contrast,
        warmth: _warmth,
        vignette: _vignette,
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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        titleSpacing: 4,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('UTSURIKOMI',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74D).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFFFB74D), width: 0.8),
                ),
                child: const Text('ISO 400',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFB74D))),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset All Edits',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _resetAllEdits,
          ),
          IconButton(
            tooltip: _isCompareMode ? 'Normal View' : 'Before/After Split',
            icon: Icon(
              _isCompareMode ? Icons.view_sidebar_rounded : Icons.compare_rounded,
              color: _isCompareMode ? const Color(0xFFFFB74D) : Colors.white70,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isCompareMode = !_isCompareMode);
            },
          ),
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
                        color: Color(0xFFFFB74D),
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main Photo Preview Canvas
            Expanded(
              child: Center(
                child: _previewing || _previewBytes == null
                    ? const CircularProgressIndicator()
                    : _isCompareMode
                        ? BeforeAfterSlider(
                            originalBytes: widget.imageBytes,
                            editedBytes: _previewBytes!,
                          )
                        : InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: _showOriginal
                                ? Image.memory(widget.imageBytes, fit: BoxFit.contain)
                                : Image.memory(_previewBytes!, fit: BoxFit.contain),
                          ),
              ),
            ),

            // Horizontal Film LUT Thumbnails Strip (VSCO Style)
            HorizontalLutStrip(
              sourceBytes: widget.imageBytes,
              selectedIndex: _toneIndex,
              filterEnabled: _filterEnabled,
              onSelectTone: (int? index) {
                setState(() {
                  if (index == null) {
                    _filterEnabled = false;
                  } else {
                    _filterEnabled = true;
                    _toneIndex = index;
                  }
                });
                _schedulePreview();
              },
            ),

            // Collapsible Tools Drawer Header (Glassmorphic)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isToolsCollapsed = !_isToolsCollapsed);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, size: 16, color: Color(0xFFFFB74D)),
                        const SizedBox(width: 8),
                        Text(
                          _isToolsCollapsed
                              ? 'Tap to Expand Tools (Grain, Light, Frame)'
                              : 'Tool Controls',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _isToolsCollapsed
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFFFFB74D),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Collapsible Tools Body
            AnimatedCrossFade(
              firstChild: _buildOptions(),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _isToolsCollapsed
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),

            // Bottom Action Bar: Hold for Original
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Listener(
                    onPointerDown: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _showOriginal = true);
                    },
                    onPointerUp: (_) => setState(() => _showOriginal = false),
                    onPointerCancel: (_) => setState(() => _showOriginal = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_rounded, size: 14, color: Colors.white70),
                          SizedBox(width: 6),
                          Text('Hold for Original',
                              style: TextStyle(color: Colors.white70, fontSize: 11)),
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

  Widget _buildOptions() {
    return SizedBox(
      height: 220,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _buildSection(
            title: 'Adjustments (Light & Color)',
            icon: Icons.tune_rounded,
            summary: 'Exposure, Contrast, Warmth, Vignette',
            isActive: _hasActiveAdjustments,
            child: Column(
              children: [
                _buildSlider(
                  label: 'Exposure',
                  value: _exposure,
                  min: -1.0,
                  max: 1.0,
                  divisions: 20,
                  valueLabel: _exposure.toStringAsFixed(2),
                  onChanged: (v) {
                    setState(() => _exposure = v);
                    _schedulePreview();
                  },
                ),
                _buildSlider(
                  label: 'Contrast',
                  value: _contrast,
                  min: -1.0,
                  max: 1.0,
                  divisions: 20,
                  valueLabel: _contrast.toStringAsFixed(2),
                  onChanged: (v) {
                    setState(() => _contrast = v);
                    _schedulePreview();
                  },
                ),
                _buildSlider(
                  label: 'Warmth',
                  value: _warmth,
                  min: -1.0,
                  max: 1.0,
                  divisions: 20,
                  valueLabel: _warmth.toStringAsFixed(2),
                  onChanged: (v) {
                    setState(() => _warmth = v);
                    _schedulePreview();
                  },
                ),
                _buildSlider(
                  label: 'Vignette',
                  value: _vignette,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  valueLabel: _vignette.toStringAsFixed(2),
                  onChanged: (v) {
                    setState(() => _vignette = v);
                    _schedulePreview();
                  },
                ),
              ],
            ),
          ),
          _buildSection(
            title: 'Film Grain',
            icon: Icons.grain_rounded,
            summary: _grain.label,
            isActive: _hasActiveGrain,
            child: _buildChoices(
              values: GrainLevel.values,
              selected: _grain,
              label: (value) => value.label,
              onSelected: (value) {
                HapticFeedback.selectionClick();
                setState(() => _grain = value);
                _schedulePreview();
              },
            ),
          ),
          _buildSection(
            title: 'Frame & Note',
            icon: Icons.crop_square_rounded,
            summary:
                '${_frame.label} · ${_frame == FrameStyle.none ? 'No Note' : (_note.enabled ? 'Note On' : 'No Note')}',
            isActive: _hasActiveFrame,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChoices(
                  values: FrameStyle.values,
                  selected: _frame,
                  label: (value) => value.label,
                  onSelected: (value) {
                    HapticFeedback.selectionClick();
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
    required bool isActive,
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
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: const Color(0xFFFFB74D)),
              if (isActive)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB74D),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
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
                selectedColor: const Color(0xFFFFB74D).withValues(alpha: 0.3),
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
            HapticFeedback.selectionClick();
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
            activeColor: const Color(0xFFFFB74D),
            min: min,
            max: max,
            divisions: divisions,
            value: value,
            label: valueLabel,
            onChangeStart: (_) => HapticFeedback.selectionClick(),
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
      const Duration(milliseconds: 50),
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
