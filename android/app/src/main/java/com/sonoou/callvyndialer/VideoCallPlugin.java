package com.sonoou.callvyndialer;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class VideoCallPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private MethodChannel channel;
    private EventChannel eventChannel;
    private VideoImsManager videoManager;
    private EventChannel.EventSink eventSink;
    private Context context;
    private ActivityPluginBinding activityBinding;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private static final int PERMISSION_REQUEST_CODE = 1001;
    private static final String[] REQUIRED_PERMISSIONS = new String[]{
        Manifest.permission.CAMERA,
        Manifest.permission.RECORD_AUDIO
    };
    public static VideoCallPlugin instance;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        instance = this;
        context = binding.getApplicationContext();

        channel = new MethodChannel(binding.getBinaryMessenger(), "com.callvyn.video");
        channel.setMethodCallHandler(this);

        eventChannel = new EventChannel(binding.getBinaryMessenger(), "com.callvyn.video/events");
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                eventSink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
            }
        });
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "isVideoCapable": {
                int subId = call.argument("subscriptionId") != null ? call.argument("subscriptionId") : 0;
                VideoImsManager mgr = new VideoImsManager(context, subId);
                videoManager = mgr;
                mgr.setEventListener(createEventListener());
                result.success(mgr.isVideoCallingCapable());
                break;
            }
            case "placeVideoCall": {
                String phoneNumber = call.argument("phoneNumber") != null ? call.argument("phoneNumber") : "";
                int subId = call.argument("subscriptionId") != null ? call.argument("subscriptionId") : 0;
                if (videoManager == null) {
                    videoManager = new VideoImsManager(context, subId);
                    videoManager.setEventListener(createEventListener());
                }
                if (checkPermissions()) {
                    videoManager.placeVideoCall(phoneNumber);
                    result.success(null);
                } else {
                    result.error("PERMISSION_DENIED", "Camera/Microphone permission required", null);
                }
                break;
            }
            case "upgradeToVideo": {
                if (checkPermissions()) {
                    if (videoManager != null) {
                        videoManager.upgradeToVideo();
                    } else {
                        CallvynInCallService.upgradeToVideoCall();
                    }
                    result.success(null);
                } else {
                    result.error("PERMISSION_DENIED", "Camera/Microphone permission required", null);
                }
                break;
            }
            case "downgradeToAudio": {
                if (videoManager != null) {
                    videoManager.downgradeToAudio();
                } else {
                    CallvynInCallService.declineVideoUpgrade();
                }
                result.success(null);
                break;
            }
            case "toggleCamera": {
                if (videoManager != null) {
                    videoManager.toggleCamera();
                }
                result.success(null);
                break;
            }
            case "setVideoMuted": {
                boolean muted = Boolean.TRUE.equals(call.argument("muted"));
                if (videoManager != null) {
                    videoManager.setVideoMuted(muted);
                }
                result.success(null);
                break;
            }
            case "endCall": {
                if (videoManager != null) {
                    videoManager.endCall();
                }
                result.success(null);
                break;
            }
            case "getVideoState": {
                result.success(videoManager != null ? videoManager.getCurrentVideoState() : 0);
                break;
            }
            case "acceptVideoUpgrade": {
                CallvynInCallService.acceptVideoUpgrade();
                result.success(null);
                break;
            }
            case "declineVideoUpgrade": {
                CallvynInCallService.declineVideoUpgrade();
                result.success(null);
                break;
            }
            default:
                result.notImplemented();
                break;
        }
    }

    private VideoImsManager.VideoCallEventListener createEventListener() {
        return new VideoImsManager.VideoCallEventListener() {
            @Override
            public void onCallConnected(String callId) {
                Map<String, Object> data = new HashMap<>();
                data.put("callId", callId);
                sendEvent("callConnected", data);
            }

            @Override
            public void onCallProgressing() {
                sendEvent("callProgressing", Collections.emptyMap());
            }

            @Override
            public void onCallTerminated(int code, String message) {
                Map<String, Object> data = new HashMap<>();
                data.put("code", code);
                data.put("message", message != null ? message : "");
                sendEvent("callTerminated", data);
            }

            @Override
            public void onCallModified(int videoDirection) {
                Map<String, Object> data = new HashMap<>();
                data.put("videoDirection", videoDirection);
                sendEvent("callModified", data);
            }

            @Override
            public void onUpgradeRequested() {
                sendEvent("upgradeRequested", Collections.emptyMap());
            }

            @Override
            public void onDowngradeRequested() {
                sendEvent("downgradeRequested", Collections.emptyMap());
            }

            @Override
            public void onCameraToggled(String cameraId) {
                Map<String, Object> data = new HashMap<>();
                data.put("cameraId", cameraId);
                sendEvent("cameraToggled", data);
            }

            @Override
            public void onVideoMuted(boolean muted) {
                Map<String, Object> data = new HashMap<>();
                data.put("muted", muted);
                sendEvent("videoMuted", data);
            }

            @Override
            public void onError(String message) {
                Map<String, Object> data = new HashMap<>();
                data.put("message", message);
                sendEvent("error", data);
            }
        };
    }

    public void dispatchEvent(String event, Map<String, Object> data) {
        sendEvent(event, data != null ? data : Collections.emptyMap());
    }

    private void sendEvent(final String event, final Map<String, Object> data) {
        mainHandler.post(() -> {
            if (eventSink != null) {
                Map<String, Object> map = new HashMap<>();
                map.put("event", event);
                map.put("data", data);
                eventSink.success(map);
            }
        });
    }

    private boolean checkPermissions() {
        Context ctx = activityBinding != null ? activityBinding.getActivity() : context;
        if (ctx == null) return false;

        boolean allGranted = true;
        for (String perm : REQUIRED_PERMISSIONS) {
            if (ContextCompat.checkSelfPermission(ctx, perm) != PackageManager.PERMISSION_GRANTED) {
                allGranted = false;
                break;
            }
        }

        if (!allGranted && activityBinding != null && activityBinding.getActivity() != null) {
            ActivityCompat.requestPermissions(
                activityBinding.getActivity(),
                REQUIRED_PERMISSIONS,
                PERMISSION_REQUEST_CODE
            );
        }
        return allGranted;
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
        }
        if (instance == this) instance = null;
        context = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activityBinding = binding;
    }

    @Override
    public void onDetachedFromActivity() {
        activityBinding = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activityBinding = binding;
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activityBinding = null;
    }
}
