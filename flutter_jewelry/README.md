# Jewelry Try-On Flutter PWA

A Progressive Web App built with Flutter for trying on jewelry with AR capabilities.

## Features

- 📱 **PWA Support**: Installable on mobile and desktop
- 📷 **Camera AR**: Real-time face detection and jewelry overlay
- 💎 **3D Models**: View and try on 3D jewelry models (GLB format)
- 🎛️ **Adjustable Controls**: Fine-tune size, position, and rotation
- 🎨 **Modern UI**: Intuitive and beautiful interface

## Setup

1. Install Flutter SDK (3.0.0 or higher)
2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Copy your GLB models to:
   - `assets/models/earring_test.glb`
   - `assets/models/ring_test.glb`

4. Run the app:
   ```bash
   flutter run -d chrome
   ```

## Building for PWA

```bash
flutter build web --release
```

The built files will be in `build/web/`.

## Usage

1. Grant camera permissions when prompted
2. Select jewelry type (Earring or Ring)
3. Adjust size, position, and rotation using sliders
4. Use Reset button to restore defaults

## Technologies

- Flutter Web
- MediaPipe Face Mesh for face detection
- Three.js for 3D rendering
- Model Viewer for GLB display

