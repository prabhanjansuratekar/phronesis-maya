package com.example.flutter_jewelry

import android.Manifest
import android.annotation.TargetApi
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class CameraWebChromeClient(private val activity: Activity) : WebChromeClient() {
    
    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    override fun onPermissionRequest(request: PermissionRequest) {
        val requestedResources = request.resources
        
        // Check if camera permission is requested
        if (requestedResources.contains(PermissionRequest.RESOURCE_VIDEO_CAPTURE)) {
            // Check if we have camera permission
            if (ContextCompat.checkSelfPermission(
                    activity,
                    Manifest.permission.CAMERA
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                // Grant permission
                request.grant(request.resources)
            } else {
                // Request permission
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.CAMERA),
                    100
                )
                // Deny for now, will be granted after permission is approved
                request.deny()
            }
        } else {
            // Grant other permissions
            request.grant(request.resources)
        }
    }
}

