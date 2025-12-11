# Mobile Access Troubleshooting Guide

## Quick Fixes

### 1. **Check Flutter is Running with Correct Settings**
Make sure you started Flutter with:
```bash
cd flutter_jewelry
flutter run -d chrome --web-hostname=0.0.0.0 --web-port=8080
```

**Important**: The `--web-hostname=0.0.0.0` flag is REQUIRED for network access.

### 2. **Verify IP Address**
Your current IP: **192.168.0.182**

Check if it's still the same:
```powershell
ipconfig | findstr /i "IPv4"
```

### 3. **Check Windows Firewall**
Windows Firewall might be blocking port 8080. Try:

**Option A: Allow through Firewall (Recommended)**
```powershell
New-NetFirewallRule -DisplayName "Flutter Web Dev Server" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
```

**Option B: Temporarily Disable Firewall (Testing Only)**
- Go to Windows Security → Firewall & network protection
- Turn off firewall temporarily to test
- **Remember to turn it back on!**

### 4. **Test Connection from Mobile**
On your phone's browser, try:
- `http://192.168.0.182:8080`
- Make sure you're on the **same WiFi network**
- Try both WiFi and mobile data to confirm it's a network issue

### 5. **Alternative: Use Python HTTP Server**
If Flutter doesn't work, you can serve the built files:

```powershell
cd flutter_jewelry\build\web
python -m http.server 8080 --bind 0.0.0.0
```

Then access: `http://192.168.0.182:8080`

### 6. **Check Router Settings**
- Some routers block device-to-device communication
- Check if "AP Isolation" or "Client Isolation" is enabled
- Disable it if enabled

### 7. **Verify Port is Listening**
Check if port 8080 is actually listening:
```powershell
netstat -an | findstr ":8080"
```

You should see something like:
```
TCP    0.0.0.0:8080           0.0.0.0:0              LISTENING
```

If you see `127.0.0.1:8080` instead, Flutter is only listening on localhost.

## Common Issues

### Issue: "This site can't be reached"
- **Cause**: Firewall blocking or wrong hostname
- **Fix**: Add firewall rule or restart with `--web-hostname=0.0.0.0`

### Issue: "Connection refused"
- **Cause**: Flutter not running or wrong port
- **Fix**: Check Flutter is running and port is correct

### Issue: Page loads but blank
- **Cause**: CORS or asset loading issues
- **Fix**: Check browser console (F12) for errors

### Issue: Works on computer but not mobile
- **Cause**: Flutter only listening on localhost
- **Fix**: Restart with `--web-hostname=0.0.0.0`

## Step-by-Step Debugging

1. **Stop Flutter** (Ctrl+C)
2. **Clear Flutter cache** (optional):
   ```bash
   flutter clean
   flutter pub get
   ```
3. **Restart with correct flags**:
   ```bash
   flutter run -d chrome --web-hostname=0.0.0.0 --web-port=8080
   ```
4. **Check Flutter output** - Look for:
   ```
   Serving at http://0.0.0.0:8080
   ```
   NOT:
   ```
   Serving at http://127.0.0.1:8080
   ```
5. **Test from computer first**:
   - Try `http://192.168.0.182:8080` on your computer
   - If this works, mobile should work too
6. **Test from mobile**:
   - Make sure same WiFi
   - Try `http://192.168.0.182:8080`

## Alternative: Use Production URL

If local network access doesn't work, you can always use the production URL:
**https://phronesis-maya.web.app**

This works from anywhere and has HTTPS (required for camera).

