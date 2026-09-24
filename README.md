# Utsurikomi

Utsurikomi is a local-first Flutter photo editor for creating film-inspired images. Choose a photo, preview a film look, add grain or a frame, and save or share the result without uploading the original image.

## Features

- Five film-inspired LUT looks:
  - Fuji Low
  - Cinematic Film
  - Cinematic Look
  - Vintage Warmth
  - Rabbit Film
- **No Filter** mode for editing without color grading
- Film grain controls:
  - No Grain
  - Subtle
  - Classic
  - Strong
- Frame styles:
  - No Frame
  - Classic White
  - Black Border
- Optional frame note with:
  - Custom text
  - Current date
  - Adjustable text size
  - Automatic text color based on the frame color
  - Adjustable frame thickness
- Full-resolution export when applying edits
- Preview processing in a background isolate
- Save edited images to the device gallery
- Share edited images with other apps
- No account, backend, analytics, advertisements, or image upload

## User flow

1. Tap **Choose from Gallery**.
2. Open **Filter** in the Editor and select a film look, or keep **No Filter**.
3. Optionally adjust **Grain**.
4. Open **Frame & Note** to choose a frame and configure the note.
5. Press **Apply**.
6. Save the result to the gallery or share it.

The Editor preview and exported Result use the same processing pipeline so that the selected filter, grain, frame, and note remain consistent.

## Privacy

Image processing is performed locally on the device. Utsurikomi does not upload photos to a server and does not require an account.

Privacy policy:

<https://tavanquangkk.github.io/utsurikomi/privacy-policy.html>

## Technology

- Flutter and Dart
- [`image`](https://pub.dev/packages/image) for decoding, pixel processing, frame composition, text rendering, and JPEG encoding
- Custom `.cube` LUT parsing and interpolation
- `image_picker` for selecting a photo
- `image_gallery_saver_plus` for saving results
- `share_plus` for sharing results
- `google_fonts` with Plus Jakarta Sans for the app UI
- `Isolate.run` to keep image processing off the UI thread

## Project structure

```text
lib/
├── main.dart
├── data/
│   └── tones.dart                 # Available film LUT definitions
├── models/
│   └── film_tone.dart             # Film tone model
├── screens/
│   ├── home_screen.dart           # Photo picker entry screen
│   ├── editor_screen.dart         # Filter, grain, frame, and note controls
│   └── result_screen.dart          # Save and share output
└── services/
    ├── cube_lut.dart              # .cube LUT parser
    └── image_processor.dart       # Background image processing pipeline

assets/
└── luts/                          # Film LUT files

test/
└── widget_test.dart                # UI and image-processing tests
```

## Requirements

- Flutter SDK compatible with Dart `^3.5.0`
- Android SDK for Android builds
- Xcode and CocoaPods for iOS builds

Check the local setup with:

```bash
flutter doctor
```

## Getting started

Clone the repository and install dependencies:

```bash
git clone https://github.com/tavanquangkk/utsurikomi.git
cd utsurikomi
flutter pub get
flutter run
```

Run on a connected Android device:

```bash
flutter devices
flutter run -d <device-id>
```

## Validation

Format the Dart sources:

```bash
dart format lib test
```

Run static analysis and tests:

```bash
flutter analyze
flutter test
```

Build a debug APK for device testing:

```bash
flutter build apk --debug
```

The output is generated at:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Release Android build

Release signing uses a local keystore. Do not commit signing files or passwords.

1. Copy the signing template:

   ```bash
   cp android/key.properties.example android/key.properties
   ```

2. Fill in the local keystore values.
3. Place the upload keystore at the configured path.
4. Increase the Flutter build number in `pubspec.yaml`.
5. Build the App Bundle:

   ```bash
   flutter build appbundle --release
   ```

The generated bundle is:

```text
build/app/outputs/bundle/release/app-release.aab
```

Every upload to Google Play must use a new, unused version code.

## Android and iOS behavior

- Android uses the system photo picker where available and does not request broad photo-library read access.
- iOS includes photo-library usage descriptions in `Info.plist`.
- Image editing is local and does not require network access after the app and font resources are available.

## Current version

The current Flutter package version is defined in `pubspec.yaml`:

```text
1.0.0+8
```

The number after `+` is the Android version code and must be increased for every new Google Play upload.

## License

This repository does not currently declare an open-source license. Contact the repository owner before redistributing the source or assets.
