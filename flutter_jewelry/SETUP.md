# Setup Instructions

## Prerequisites
- Flutter SDK 3.0.0 or higher
- Chrome browser (for testing)

## Steps

1. **Install Flutter dependencies:**
   ```bash
   cd flutter_jewelry
   flutter pub get
   ```

2. **Copy GLB models to web directory:**
   ```bash
   # From the project root
   cp earring_test.glb flutter_jewelry/web/
   cp ring_test.glb flutter_jewelry/web/
   ```

3. **Run the app:**
   ```bash
   flutter run -d chrome
   ```

4. **Build for production:**
   ```bash
   flutter build web --release
   ```

## Notes
- The app requires camera permissions
- For best results, use Chrome on desktop or mobile
- The AR functionality uses MediaPipe Face Mesh which requires HTTPS in production

