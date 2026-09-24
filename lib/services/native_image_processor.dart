import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'cube_lut.dart';
import 'image_processor.dart';

// Native FFI C Types
typedef NativeProcessFuncC = Pointer<Uint8> Function(
  Pointer<Uint8> srcPtr,
  IntPtr srcLen,
  Pointer<Float> lutPtr,
  IntPtr lutLen,
  Int32 lutSize,
  Bool applyFilter,
  Int32 grainAmount,
  Int32 frameIndex,
  Pointer<Utf8> noteTextPtr,
  Pointer<Utf8> noteDatePtr,
  Int32 noteFontSize,
  Int32 frameThickness,
  Float exposure,
  Float contrast,
  Float warmth,
  Float vignette,
  Int32 maxDimension,
  Pointer<IntPtr> outLenPtr,
);

typedef NativeProcessFuncDart = Pointer<Uint8> Function(
  Pointer<Uint8> srcPtr,
  int srcLen,
  Pointer<Float> lutPtr,
  int lutLen,
  int lutSize,
  bool applyFilter,
  int grainAmount,
  int frameIndex,
  Pointer<Utf8> noteTextPtr,
  Pointer<Utf8> noteDatePtr,
  int noteFontSize,
  int frameThickness,
  double exposure,
  double contrast,
  double warmth,
  double vignette,
  int maxDimension,
  Pointer<IntPtr> outLenPtr,
);

typedef NativeFreeFuncC = Void Function(Pointer<Uint8> ptr, IntPtr len);
typedef NativeFreeFuncDart = void Function(Pointer<Uint8> ptr, int len);

class NativeImageProcessor {
  static DynamicLibrary? _lib;
  static NativeProcessFuncDart? _processFunc;
  static NativeFreeFuncDart? _freeFunc;
  static bool _initialized = false;
  static bool _hasNativeLib = false;

  static void _init() {
    if (_initialized) return;
    _initialized = true;

    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libutsurikomi_native.so');
      } else if (Platform.isMacOS) {
        final dylibFile = File('rust/target/release/libutsurikomi_native.dylib');
        if (dylibFile.existsSync()) {
          _lib = DynamicLibrary.open(dylibFile.path);
        } else {
          _lib = DynamicLibrary.process();
        }
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process();
      }

      if (_lib != null) {
        _processFunc = _lib!
            .lookup<NativeFunction<NativeProcessFuncC>>('process_image_native')
            .asFunction<NativeProcessFuncDart>();
        _freeFunc = _lib!
            .lookup<NativeFunction<NativeFreeFuncC>>('free_native_buffer')
            .asFunction<NativeFreeFuncDart>();
        _hasNativeLib = true;
      }
    } catch (e) {
      _hasNativeLib = false;
    }
  }

  static bool get isNativeSupported {
    _init();
    return _hasNativeLib && _processFunc != null && _freeFunc != null;
  }

  static Future<Uint8List> processBytes({
    required Uint8List sourceBytes,
    required String lutAssetPath,
    required String toneId,
    GrainLevel grain = GrainLevel.off,
    FrameStyle frame = FrameStyle.none,
    NoteOptions note = const NoteOptions(),
    bool applyFilter = true,
    double exposure = 0.0,
    double contrast = 0.0,
    double warmth = 0.0,
    double vignette = 0.0,
    int? maxDimension = 2000,
  }) async {
    final bool hasAdjustments =
        exposure != 0.0 || contrast != 0.0 || warmth != 0.0 || vignette > 0.0;

    if (!applyFilter &&
        grain == GrainLevel.off &&
        frame == FrameStyle.none &&
        !note.enabled &&
        !hasAdjustments) {
      return sourceBytes;
    }

    if (!isNativeSupported) {
      return ImageProcessor.processBytes(
        sourceBytes: sourceBytes,
        lutAssetPath: lutAssetPath,
        toneId: toneId,
        grain: grain,
        frame: frame,
        note: note,
        applyFilter: applyFilter,
        exposure: exposure,
        contrast: contrast,
        warmth: warmth,
        vignette: vignette,
        maxDimension: maxDimension,
      );
    }

    final CubeLut? lut = applyFilter ? await ImageProcessor.getLut(lutAssetPath) : null;
    final Float32List lutData = lut?.data ?? Float32List(0);
    final int lutSize = lut?.size ?? 0;

    return _processNativeSync(
      sourceBytes: sourceBytes,
      lutData: lutData,
      lutSize: lutSize,
      applyFilter: applyFilter,
      grainAmount: grain.amount,
      frameIndex: frame.index,
      noteText: note.text.trim(),
      noteDate: note.includeDate ? ImageProcessor.formatDate(DateTime.now()) : '',
      noteFontSize: note.fontSize,
      frameThickness: note.frameThickness,
      exposure: exposure,
      contrast: contrast,
      warmth: warmth,
      vignette: vignette,
      maxDimension: maxDimension ?? 0,
    );
  }

  static Uint8List _processNativeSync({
    required Uint8List sourceBytes,
    required Float32List lutData,
    required int lutSize,
    required bool applyFilter,
    required int grainAmount,
    required int frameIndex,
    required String noteText,
    required String noteDate,
    required int noteFontSize,
    required int frameThickness,
    required double exposure,
    required double contrast,
    required double warmth,
    required double vignette,
    required int maxDimension,
  }) {
    final Pointer<Uint8> srcPtr = malloc.allocate<Uint8>(sourceBytes.length);
    final Uint8List srcList = srcPtr.asTypedList(sourceBytes.length);
    srcList.setAll(0, sourceBytes);

    Pointer<Float> lutPtr = nullptr;
    if (lutData.isNotEmpty) {
      lutPtr = malloc.allocate<Float>(lutData.length * 4);
      final Float32List lutList = lutPtr.asTypedList(lutData.length);
      lutList.setAll(0, lutData);
    }

    final Pointer<Utf8> textPtr = noteText.toNativeUtf8();
    final Pointer<Utf8> datePtr = noteDate.toNativeUtf8();
    final Pointer<IntPtr> outLenPtr = malloc.allocate<IntPtr>(1);

    try {
      final Pointer<Uint8> resultPtr = _processFunc!(
        srcPtr,
        sourceBytes.length,
        lutPtr,
        lutData.length,
        lutSize,
        applyFilter,
        grainAmount,
        frameIndex,
        textPtr,
        datePtr,
        noteFontSize,
        frameThickness,
        exposure,
        contrast,
        warmth,
        vignette,
        maxDimension,
        outLenPtr,
      );

      if (resultPtr == nullptr) {
        throw Exception('Native Rust image processing failed');
      }

      final int outLen = outLenPtr.value;
      final Uint8List nativeBytes = resultPtr.asTypedList(outLen);
      final Uint8List outputBytes = Uint8List.fromList(nativeBytes);

      _freeFunc!(resultPtr, outLen);
      return outputBytes;
    } finally {
      malloc.free(srcPtr);
      if (lutPtr != nullptr) malloc.free(lutPtr);
      malloc.free(textPtr);
      malloc.free(datePtr);
      malloc.free(outLenPtr);
    }
  }
}
