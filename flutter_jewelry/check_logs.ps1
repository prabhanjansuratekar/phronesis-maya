# Helper script to check Flutter logs
Write-Host "Checking Flutter logs for device 3efd450d..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

flutter logs --device-id 3efd450d 2>&1 | Select-String -Pattern "I/flutter|ML Kit|MediaPipe|FaceDetector|InputImage|Processing|Detected|Error|Exception|face detected|Initializing|MediaPipe" | ForEach-Object {
    $line = $_.Line
    if ($line -match "Error|Exception|error") {
        Write-Host $line -ForegroundColor Red
    } elseif ($line -match "Detected|face detected|Successfully") {
        Write-Host $line -ForegroundColor Green
    } elseif ($line -match "ML Kit|MediaPipe|InputImage|Processing") {
        Write-Host $line -ForegroundColor Yellow
    } else {
        Write-Host $line
    }
}

