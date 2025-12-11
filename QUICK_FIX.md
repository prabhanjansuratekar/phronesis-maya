# Quick Fix for Mobile Access

## 🔴 Problem Found
Flutter is only listening on `localhost` (`[::1]:8080`), not on your network IP. That's why mobile can't connect.

## ✅ Solution

### Step 1: Stop Current Flutter
Press `Ctrl+C` in the terminal where Flutter is running.

### Step 2: Restart with Network Access
Run this command:
```bash
cd flutter_jewelry
flutter run -d chrome --web-hostname=0.0.0.0 --web-port=8080
```

**OR** use the batch file I created:
```bash
START_FLUTTER_NETWORK.bat
```

### Step 3: Verify It's Listening
After restarting, check the Flutter output. You should see:
```
Serving at http://0.0.0.0:8080
```

NOT:
```
Serving at http://127.0.0.1:8080
```

### Step 4: Access from Mobile
On your phone's browser, go to:
```
http://192.168.0.182:8080
```

## 🚀 Alternative: Use Production URL

Since you already deployed to production, you can also use:
**https://phronesis-maya.web.app**

This works from anywhere and has HTTPS (required for camera access).

## 🔧 Firewall
I've added a firewall rule to allow port 8080. If it still doesn't work, you may need to:
1. Check Windows Firewall settings
2. Ensure both devices are on the same WiFi network
3. Try disabling firewall temporarily to test

