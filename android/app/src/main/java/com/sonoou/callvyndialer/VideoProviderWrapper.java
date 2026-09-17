package com.sonoou.callvyndialer;

import android.content.Context;
import android.os.Build;
import android.telecom.InCallService;
import android.util.Log;
import android.view.Surface;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

public class VideoProviderWrapper {
    private static final String TAG = "VideoProviderWrapper";
    public static VideoProviderWrapper instance;

    private final Context context;
    private Surface displaySurface = null;
    private Surface previewSurface = null;
    private String selectedCameraId = null;
    private boolean isSurfaceReady = false;
    private boolean isCameraOpen = false;
    private boolean pendingCameraOpen = false;

    public VideoProviderWrapper(Context context) {
        this.context = context != null ? context.getApplicationContext() : null;
        instance = this;
        this.selectedCameraId = VideoImsManager.getCameraId(this.context, false);
        Log.d(TAG, "VideoProviderWrapper initialized, default camera: " + selectedCameraId);
    }

    public void setDisplaySurface(Surface surface) {
        Log.d(TAG, "🖥️ onSetDisplaySurface: surface=" + (surface != null && surface.isValid() ? "VALID" : "NULL") + ", hashCode=" + (surface != null ? surface.hashCode() : 0));
        this.displaySurface = surface;
        InCallService.VideoCall vCall = getVideoCall();
        if (vCall != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                vCall.setDisplaySurface(surface);
            } catch (Exception e) {
                Log.e(TAG, "Error vCall.setDisplaySurface: " + e.getMessage(), e);
            }
        }
        checkAndInitializeVideo();
    }

    public void setPreviewSurface(Surface surface) {
        Log.d(TAG, "📷 onSetPreviewSurface: surface=" + (surface != null && surface.isValid() ? "VALID" : "NULL") + ", hashCode=" + (surface != null ? surface.hashCode() : 0));
        this.previewSurface = surface;
        InCallService.VideoCall vCall = getVideoCall();
        if (vCall != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                vCall.setPreviewSurface(surface);
            } catch (Exception e) {
                Log.e(TAG, "Error vCall.setPreviewSurface: " + e.getMessage(), e);
            }
        }
        checkAndInitializeVideo();
    }

    public void setCamera(String cameraId) {
        Log.d(TAG, "📸 onSetCamera requested: cameraId=" + cameraId + ", surfacesReady=" + isSurfaceReady);
        this.selectedCameraId = cameraId != null ? cameraId : VideoImsManager.getCameraId(this.context, false);
        if (isSurfaceReady) {
            openCameraNow(false);
        } else {
            pendingCameraOpen = true;
            Log.d(TAG, "⏳ Camera pending - waiting for display/preview surfaces");
        }
    }

    private void checkAndInitializeVideo() {
        boolean hasDisplay = displaySurface != null && displaySurface.isValid();
        boolean hasPreview = previewSurface != null && previewSurface.isValid();

        if (hasDisplay || hasPreview) {
            isSurfaceReady = true;
            Log.d(TAG, "✅ Surface available (display=" + hasDisplay + ", preview=" + hasPreview + "). Initializing camera...");
            openCameraNow(false);
        } else {
            isSurfaceReady = false;
            Log.d(TAG, "⚠️ Waiting for surfaces: display=" + hasDisplay + ", preview=" + hasPreview);
        }
    }

    public void openCameraNow(boolean force) {
        InCallService.VideoCall vCall = getVideoCall();
        if (vCall == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            Log.w(TAG, "Cannot open camera: videoCall is null or SDK < 23");
            return;
        }

        if (isCameraOpen && !force) {
            Log.d(TAG, "Camera already open and active with ID: " + selectedCameraId);
            return;
        }

        try {
            String camId = selectedCameraId != null ? selectedCameraId : VideoImsManager.getCameraId(this.context, false);
            Log.d(TAG, "📸 Executing Step: setCamera(" + camId + ") on active VideoCall");
            vCall.setCamera(camId);
            vCall.setDeviceOrientation(0);
            vCall.setZoom(1.0f);
            vCall.requestCameraCapabilities();
            isCameraOpen = true;
            pendingCameraOpen = false;

            if (VideoCallPlugin.instance != null) {
                Map<String, Object> data = new HashMap<>();
                data.put("cameraId", camId);
                VideoCallPlugin.instance.dispatchEvent("cameraReady", data);
            }
        } catch (Exception e) {
            Log.e(TAG, "❌ Failed to open camera: " + e.getMessage(), e);
            if (VideoCallPlugin.instance != null) {
                Map<String, Object> data = new HashMap<>();
                data.put("message", "Camera failed: " + e.getMessage());
                VideoCallPlugin.instance.dispatchEvent("error", data);
            }
        }
    }

    public void toggleCamera(boolean useBack) {
        String newCamId = VideoImsManager.getCameraId(this.context, useBack);
        selectedCameraId = newCamId;
        Log.d(TAG, "Toggling camera to: " + newCamId + " (useBack=" + useBack + ")");
        openCameraNow(true);
        if (VideoCallPlugin.instance != null) {
            Map<String, Object> data = new HashMap<>();
            data.put("cameraId", newCamId);
            VideoCallPlugin.instance.dispatchEvent("cameraToggled", data);
        }
    }

    private InCallService.VideoCall getVideoCall() {
        if (CallvynInCallService.activeCall != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            InCallService.VideoCall vCall = CallvynInCallService.activeCall.getVideoCall();
            if (vCall != null) return vCall;
        }
        return CallvynInCallService.currentVideoCall;
    }

    public void release() {
        Log.d(TAG, "Releasing VideoProviderWrapper");
        InCallService.VideoCall vCall = getVideoCall();
        if (vCall != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                vCall.setCamera(null);
            } catch (Exception ignored) {}
        }
        isCameraOpen = false;
        isSurfaceReady = false;
        pendingCameraOpen = false;
        displaySurface = null;
        previewSurface = null;
        selectedCameraId = null;
    }
}
