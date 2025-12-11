# Testing the Flutter Jewelry PWA

## Current Status

The Flutter PWA has been created and built successfully. The app structure is complete with:
- ✅ Flutter project setup
- ✅ Dependencies installed
- ✅ UI components (Jewelry Selector, Control Panel)
- ✅ Camera AR integration (camera_ar.html)
- ✅ GLB models copied
- ✅ PWA manifest configured

## To Test Locally

1. **Navigate to the Flutter project:**
   ```bash
   cd flutter_jewelry
   ```

2. **Run the app for mobile access:**
   ```bash
   flutter run -d chrome --web-port=8080 --web-hostname=0.0.0.0
   ```
   
   Or for desktop only:
   ```bash
   flutter run -d chrome --web-port=8080
   ```

3. **Wait for compilation** (takes ~30-40 seconds)

4. **Access from different devices:**
   - **Desktop (same computer):** `http://localhost:8080`
   - **Mobile (same WiFi):** `http://192.168.0.182:8080`
   - Replace `192.168.0.182` with your actual local IP if different

## Expected Behavior

1. You should see:
   - Dark-themed UI with "Jewelry Try-On" title
   - A welcome screen with "Enable Camera for AR" button
   - Jewelry selector at the top (Earring/Ring)
   - Control panel at the bottom (when camera is enabled)

2. Click "Enable Camera for AR" to:
   - Request camera permissions
   - Load the AR view with face detection
   - Show jewelry overlay on your face

3. Use the sliders to adjust:
   - Size (0.5x - 2.0x)
   - Position X/Y (-50 to +50)
   - Rotation (-180° to +180°)

## Troubleshooting

If you see a blank screen:
1. Check browser console (F12) for errors
2. Ensure camera permissions are granted
3. Try hard refresh (Ctrl+Shift+R)
4. Check that port 8080 is available

If camera doesn't work:
- Ensure you're using HTTPS in production (required for camera)
- For local testing, Chrome allows camera on localhost
- Check browser console for MediaPipe errors

## Files Structure

```
flutter_jewelry/
├── lib/
│   ├── main.dart              # App entry
│   ├── screens/
│   │   └── home_screen.dart   # Main screen
│   └── widgets/
│       ├── camera_view.dart    # Camera integration
│       ├── jewelry_selector.dart
│       └── control_panel.dart
├── web/
│   ├── index.html             # Flutter web entry
│   ├── camera_ar.html         # AR implementation
│   ├── manifest.json          # PWA config
│   ├── earring_test.glb       # 3D models
│   └── ring_test.glb
└── build/web/                 # Built files
```

## Next Steps

Once the basic UI is visible:
1. Test camera access
2. Verify face detection works
3. Test jewelry overlay positioning
4. Adjust sliders to fine-tune placement

