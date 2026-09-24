# Utsurikomi

Utsurikomi is a local-first, high-performance Flutter photo editor and film camera app for creating film-inspired images. Take photos directly with a retro film viewfinder or choose photos from your gallery, apply custom 3D LUT color grades, adjust film grain and lighting, add vintage frames with custom notes, and save or share the result without uploading images to any server.

---

## Key Features

- **High-Performance Native Engine:**
  - Powered by **Rust** with SIMD acceleration and **Rayon** multi-threading for sub-50ms high-resolution image processing (10x–50x faster than pure Dart).
  - EXIF orientation auto-correction.
  - Transparent `dart:ffi` binding with fallback to Dart Isolate.

- **In-App Retro Film Camera Viewfinder:**
  - Built-in vintage film viewfinder with real-time film tone selection.
  - Shutter button with haptic feedback.
  - Flash control (Off, Auto, Always) and Camera Flip (Front/Rear).

- **Five Film-Inspired LUT Looks:**
  - Fuji Low
  - Cinematic Film
  - Cinematic Look
  - Vintage Warmth
  - Rabbit Film
  - **No Filter** mode for editing without color grading.

- **Horizontal Film LUT Thumbnail Strip (VSCO / Lightroom Style):**
  - Live thumbnail previews of your photo for each film tone for instant visual selection.

- **Light & Color Adjustments:**
  - **Exposure:** Fine-tune photo brightness.
  - **Contrast:** Adjust dark and light tones.
  - **Warmth (Temperature):** Add vintage warmth (golden tones) or coolness (cool blue).
  - **Vignette:** Add classic lens edge darkening.

- **Film Grain Controls:**
  - No Grain, Subtle, Classic, Strong.

- **Frame Styles & Notes:**
  - No Frame, Classic White, Black Border.
  - Optional note with custom text, current date, text size, and automatic text color matching frame color.

- **Interactive Before / After Split View:**
  - Drag-to-compare split view slider with glassmorphism handle.

- **Pinch-to-Zoom & Pan Canvas (`InteractiveViewer`):**
  - Zoom in with two fingers to inspect fine film grain and text details.

- **Collapsible Tools Drawer:**
  - Collapse the bottom control drawer to 40px height to expand the photo preview canvas to full screen.

- **Haptic Feedback & Micro-interactions:**
  - Tactile vibration feedback on slider changes, LUT selection, button taps, and shutter clicks.

- **1-Tap Quick Reset ("Reset All"):**
  - Instantly reset all adjustments and effects back to default values.

- **Privacy First:**
  - 100% local processing. No account, no backend, no analytics, no ads, and no image uploads.

---

## User Flow

1. Tap **Take Film Photo** to capture with the retro viewfinder or **Choose from Gallery**.
2. Select a film LUT tone from the **Horizontal LUT Strip**.
3. Open **Adjustments** to fine-tune Exposure, Contrast, Warmth, or Vignette.
4. Adjust **Film Grain** level and select **Frame & Note** style.
5. Tap **Apply** to render full-resolution result.
6. Save to gallery or share directly to other apps.

---

## Technology Stack

- **Flutter & Dart:** UI framework and state management.
- **Rust (Native Core):** `image`, `rayon` (multi-threading), `ab_glyph` for SIMD-accelerated pixel processing, 3D LUT sampling, grain noise generation, and JPEG encoding.
- **`dart:ffi`:** Low-latency C-ABI binding between Flutter and Rust.
- **`camera`:** In-app retro viewfinder camera controller.
- **`image_picker`:** Gallery photo selection using system photo picker.
- **`image_gallery_saver_plus`:** Save outputs to system gallery.
- **`share_plus`:** Native OS sharing.

---

## Project Structure

```text
lib/
├── main.dart
├── data/
│   └── tones.dart                 # Film LUT definitions
├── models/
│   └── film_tone.dart             # Film tone model
├── screens/
│   ├── home_screen.dart           # Entry screen (Take Photo / Gallery)
│   ├── camera_screen.dart         # Retro film viewfinder screen
│   ├── editor_screen.dart         # Filter, Adjustments, Grain & Frame controls
│   └── result_screen.dart         # Developed film view, save & share
├── services/
│   ├── cube_lut.dart              # .cube LUT parser
│   ├── image_processor.dart       # Main image processing entry point
│   └── native_image_processor.dart # FFI binding to Rust native engine
└── widgets/
    ├── before_after_slider.dart   # Interactive Before/After split view
    └── horizontal_lut_strip.dart  # VSCO-style LUT thumbnail carousel

rust/
├── Cargo.toml                     # Rust crate definition (cdylib & staticlib)
├── assets/fonts/                  # Embedded fonts for note rendering
└── src/
    └── lib.rs                     # High-performance Rust image engine

scripts/
└── build_android.sh               # Cargo NDK build script for Android JNI .so files

android/app/src/main/jniLibs/      # Compiled native libraries (.so)
├── arm64-v8a/
├── armeabi-v7a/
└── x86_64/
```

---

## Development & Building

### Requirements

- Flutter SDK `^3.5.0`
- Rust toolchain (`rustc` & `cargo`)
- Android NDK (for building Rust Android binaries)

### Building Rust Native Libraries

To rebuild the Android `.so` shared libraries:

```bash
chmod +x scripts/build_android.sh
./scripts/build_android.sh
```

To build the Rust library for macOS dev testing:

```bash
cd rust
cargo build --release
```

### Running the App

```bash
flutter pub get
flutter run
```

Run on a specific connected Android device:

```bash
flutter devices
flutter run -d <device-id>
```

---

## Validation & Testing

Format Dart code:

```bash
dart format lib test
```

Run static analysis & unit tests:

```bash
flutter analyze
flutter test
```

Build debug APK:

```bash
flutter build apk --debug
```

Build production Release App Bundle (`.aab`) for Google Play Store:

```bash
flutter build appbundle --release
```

---

## Privacy Policy

Image processing is performed entirely on your device:
<https://tavanquangkk.github.io/utsurikomi/privacy-policy.html>

---

## Version

Current version in `pubspec.yaml`: `1.0.0+8`
