# Project Notes (2025-12-11)

## Current status
- Android: earrings now render at detected ear positions (ML Kit landmarks). Ring rendering remains available.
- MediaPipe face mesh is disabled (fallback to ML Kit only) to avoid `FaceDetector not initialized` errors from `face_detection_tflite`.
- Model rendering uses `model_viewer_plus` 1.9.3 with asset paths (`web/earring_test.glb`, `web/ring_test.glb`). Keys are stable to avoid platform-view thrash.
- Web/PWA flow was de-prioritized (user focus is Android); MediaPipe on web still not reliable.

## How to run (Android)
1. Ensure Flutter SDK 3.9.x (Dart 3.9.x).
2. From `flutter_jewelry/`:
   - `flutter pub get`
   - `flutter run -d <device_id>`
3. Permissions: the app requests camera on launch; accept the prompt.

## Key implementation notes
- Face tracking: ML Kit `google_mlkit_face_detection` provides ear landmarks. MediaPipe path is stubbed/disabled.
- Earring placement: positions computed in `_getEarringPositions`; widgets keyed as `earring_<index>` with asset `web/earring_test.glb`.
- ModelViewer: uses asset paths directly (no temp file copy). Stable keys prevent repeated platform view creation.
- Assets declared in `pubspec.yaml`: `web/camera_ar.html`, `web/earring_test.glb`, `web/ring_test.glb`.
- .gitignore added to keep build artifacts, .dart_tool, and platform temp files out of git.

## Known issues / next steps
- ModelViewer still noisy in logs; if fetch errors reappear, consider custom HTML loading `model-viewer.min.js` from CDN or bundling it manually.
- MediaPipe face mesh is off; if higher accuracy needed, revisit `face_detection_tflite` init and ensure proper model/task setup.
- Web/PWA not fixed (camera prompt + MediaPipe load issues); revisit only if web becomes a requirement.

## Branch / remote
- Repo initialized locally; add `origin` and push when ready:  
  `git remote add origin https://github.com/prabhanjansuratekar/phronesis-maya.git`  
  `git push -u origin main`

