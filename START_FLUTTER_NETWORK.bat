@echo off
echo Starting Flutter with network access...
echo.
echo Make sure to stop any running Flutter instances first (Ctrl+C)
echo.
cd flutter_jewelry
flutter run -d chrome --web-hostname=0.0.0.0 --web-port=8080
pause

