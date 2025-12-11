# Mobile Access Instructions

## Your Local IP Address
**192.168.0.182**

## Steps to Access from Mobile

1. **On your computer, run Flutter with network access:**
   ```bash
   cd flutter_jewelry
   flutter run -d chrome --web-port=8080 --web-hostname=0.0.0.0
   ```

2. **Wait for compilation** (30-40 seconds)

3. **On your mobile device (same WiFi network):**
   - Open your mobile browser (Chrome, Safari, etc.)
   - Navigate to: **`http://192.168.0.182:8080`**

4. **Grant camera permissions** when prompted on mobile

## Important Notes

- ✅ Both devices must be on the same WiFi network
- ✅ Your computer's firewall may block the connection - allow port 8080 if needed
- ✅ The mobile browser will request camera permissions - grant them for AR to work
- ✅ For best results, use Chrome on Android or Safari on iOS

## Troubleshooting

**Can't connect from mobile?**
1. Check that both devices are on the same WiFi
2. Verify your computer's IP: `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
3. Check Windows Firewall - allow port 8080
4. Try disabling firewall temporarily to test

**Camera not working on mobile?**
- Mobile browsers require HTTPS for camera access in production
- For local testing, some browsers allow camera on localhost/IP addresses
- If camera doesn't work, the UI will still be visible for testing

## Alternative: Build and Serve

If `flutter run` doesn't work for network access:

1. Build the web app:
   ```bash
   flutter build web
   ```

2. Serve from build directory:
   ```bash
   cd build/web
   python -m http.server 8080 --bind 0.0.0.0
   ```

3. Access from mobile: `http://192.168.0.182:8080`


