package com.sonoou.callvyndialer;

import android.app.ActivityManager;
import android.app.KeyguardManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.usage.UsageEvents;
import android.app.usage.UsageStatsManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.provider.ContactsContract;
import android.provider.Settings;
import android.telecom.Call;
import android.telecom.CallAudioState;
import android.telecom.InCallService;
import android.telecom.PhoneAccountHandle;
import android.telecom.TelecomManager;
import android.telecom.VideoProfile;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.Surface;
import android.view.View;
import android.view.WindowManager;
import android.widget.RemoteViews;
import android.widget.TextView;

import androidx.core.app.NotificationCompat;

import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

public class CallvynInCallService extends InCallService {
    public static final int NOTIFICATION_INCOMING_ID = 1002;
    public static final int NOTIFICATION_ONGOING_ID = 1005;
    public static final String CHANNEL_INCOMING_ID = "callvyn_incoming_call_channel";
    public static final String CHANNEL_ONGOING_ID = "callvyn_ongoing_call_channel";

    public static CallvynInCallService instance;
    public static Call activeCall;
    public static long callConnectTimeMs = 0L;
    private static final Handler staticHandler = new Handler(Looper.getMainLooper());

    public static InCallService.VideoCall currentVideoCall;
    public static Surface currentRemoteSurface;
    public static Surface currentLocalSurface;
    private static String lastSelectedCameraId;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private View overlayView;
    private WindowManager windowManager;
    private Runnable ongoingTimerRunnable;

    public static void sendDtmf(final char digit) {
        try {
            final Call call = activeCall;
            if (call != null) {
                call.playDtmfTone(digit);
                staticHandler.postDelayed(() -> {
                    try {
                        call.stopDtmfTone();
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }, 200);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static boolean isCallVideo(Call call) {
        if (call == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false;
        int videoState = call.getDetails() != null ? call.getDetails().getVideoState() : VideoProfile.STATE_AUDIO_ONLY;
        if (VideoProfile.isVideo(videoState) ||
            VideoProfile.isBidirectional(videoState) ||
            VideoProfile.isTransmissionEnabled(videoState) ||
            VideoProfile.isReceptionEnabled(videoState)) {
            return true;
        }
        Bundle extras = call.getDetails() != null ? call.getDetails().getExtras() : null;
        if (extras != null) {
            int extraVideoState = extras.getInt(TelecomManager.EXTRA_START_CALL_WITH_VIDEO_STATE, VideoProfile.STATE_AUDIO_ONLY);
            if (VideoProfile.isVideo(extraVideoState) || VideoProfile.isBidirectional(extraVideoState)) {
                return true;
            }
            if (extras.getBoolean("videocall", false) ||
                extras.getBoolean("com.android.phone.extra.video", false) ||
                extras.getBoolean("org.codeaurora.extra.VT_CALL", false) ||
                extras.getBoolean("android.intent.extra.VIDEO_CALL", false)) {
                return true;
            }
        }
        return false;
    }

    public static void setRemoteSurface(Surface surface) {
        currentRemoteSurface = surface;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            InCallService.VideoCall vCall = (activeCall != null ? activeCall.getVideoCall() : null);
            if (vCall == null) vCall = currentVideoCall;
            if (vCall != null) {
                try {
                    vCall.setDisplaySurface(surface);
                } catch (Exception e) {
                    Log.e("CallvynVideo", "setRemoteSurface error: " + e.getMessage(), e);
                }
            }
        }
        if (VideoProviderWrapper.instance != null) {
            VideoProviderWrapper.instance.setDisplaySurface(surface);
        }
    }

    public static void setLocalSurface(Surface surface) {
        currentLocalSurface = surface;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            InCallService.VideoCall vCall = (activeCall != null ? activeCall.getVideoCall() : null);
            if (vCall == null) vCall = currentVideoCall;
            if (vCall != null) {
                try {
                    vCall.setPreviewSurface(surface);
                } catch (Exception e) {
                    Log.e("CallvynVideo", "setLocalSurface error: " + e.getMessage(), e);
                }
            }
        }
        if (VideoProviderWrapper.instance != null) {
            VideoProviderWrapper.instance.setPreviewSurface(surface);
        }
    }

    public static void attachSurfaces(InCallService.VideoCall videoCall) {
        if (videoCall == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return;
        try {
            Surface rSurface = currentRemoteSurface;
            if (rSurface != null && rSurface.isValid()) {
                Log.d("CallvynVideo", "attachSurfaces: setDisplaySurface " + rSurface);
                videoCall.setDisplaySurface(rSurface);
            }

            Surface lSurface = currentLocalSurface;
            if (lSurface != null && lSurface.isValid()) {
                Log.d("CallvynVideo", "attachSurfaces: setPreviewSurface " + lSurface);
                videoCall.setPreviewSurface(lSurface);
            }

            videoCall.setDeviceOrientation(0);
            videoCall.setZoom(1.0f);
        } catch (Exception e) {
            Log.e("CallvynVideo", "attachSurfaces error: " + e.getMessage(), e);
        }
    }

    public static void setupCamera(InCallService.VideoCall videoCall, Context context, boolean useBack, boolean force) {
        String camId = VideoImsManager.getCameraId(context != null ? context : instance, useBack);
        if (VideoProviderWrapper.instance != null) {
            VideoProviderWrapper.instance.setCamera(camId);
        } else if (videoCall != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                videoCall.setCamera(camId);
                videoCall.setDeviceOrientation(0);
                videoCall.setZoom(1.0f);
                videoCall.requestCameraCapabilities();
            } catch (Exception e) {
                Log.e("CallvynVideo", "setupCamera direct error: " + e.getMessage(), e);
            }
        }
    }

    public static void syncVideoSession(InCallService.VideoCall videoCall, Context context, boolean useBack) {
        if (videoCall == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return;
        Log.d("CallvynVideo", "syncVideoSession called (useBack=" + useBack + ")");
        setupCamera(videoCall, context, useBack, false);
        attachSurfaces(videoCall);
    }

    public static void switchCamera(boolean useBack) {
        if (VideoProviderWrapper.instance != null) {
            VideoProviderWrapper.instance.toggleCamera(useBack);
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            InCallService.VideoCall vCall = (activeCall != null ? activeCall.getVideoCall() : null);
            if (vCall == null) vCall = currentVideoCall;
            if (vCall != null) {
                String camId = VideoImsManager.getCameraId(instance, useBack);
                try {
                    vCall.setCamera(camId);
                } catch (Exception e) {
                    Log.e("CallvynVideo", "switchCamera direct error: " + e.getMessage(), e);
                }
            }
        }
    }

    public static void answerCall(boolean asVideo) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Call call = activeCall;
                boolean isVid = asVideo || isCallVideo(call);
                int targetState = isVid ? VideoProfile.STATE_BIDIRECTIONAL : VideoProfile.STATE_AUDIO_ONLY;
                if (call != null) {
                    call.answer(targetState);
                }
                if (isVid) {
                    InCallService.VideoCall vCall = (call != null ? call.getVideoCall() : null);
                    if (vCall == null) vCall = currentVideoCall;
                    Context ctx = instance != null ? instance : MainActivity.instance;
                    syncVideoSession(vCall, ctx, false);
                    staticHandler.postDelayed(() -> {
                        InCallService.VideoCall vCallRetry = (activeCall != null ? activeCall.getVideoCall() : null);
                        if (vCallRetry == null) vCallRetry = currentVideoCall;
                        if (vCallRetry != null) {
                            syncVideoSession(vCallRetry, instance != null ? instance : MainActivity.instance, false);
                            try {
                                vCallRetry.sendSessionModifyRequest(new VideoProfile(
                                    VideoProfile.STATE_BIDIRECTIONAL,
                                    VideoProfile.QUALITY_DEFAULT
                                ));
                            } catch (Exception e) {
                                e.printStackTrace();
                            }
                        }
                    }, 500);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static void upgradeToVideoCall() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                InCallService.VideoCall vCall = (activeCall != null ? activeCall.getVideoCall() : null);
                if (vCall == null) vCall = currentVideoCall;
                if (vCall != null) {
                    syncVideoSession(vCall, instance != null ? instance : MainActivity.instance, false);
                    VideoProfile requestProfile = new VideoProfile(
                        VideoProfile.STATE_BIDIRECTIONAL,
                        VideoProfile.QUALITY_DEFAULT
                    );
                    vCall.sendSessionModifyRequest(requestProfile);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static void acceptVideoUpgrade() {
        InCallService.VideoCall vCall = (activeCall != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) ? activeCall.getVideoCall() : null;
        if (vCall == null) vCall = currentVideoCall;
        if (vCall != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            final VideoProfile responseProfile = new VideoProfile(
                VideoProfile.STATE_BIDIRECTIONAL,
                VideoProfile.QUALITY_DEFAULT
            );
            syncVideoSession(vCall, instance != null ? instance : MainActivity.instance, false);
            vCall.sendSessionModifyResponse(responseProfile);
            staticHandler.postDelayed(() -> {
                try {
                    InCallService.VideoCall vCallRetry = (activeCall != null ? activeCall.getVideoCall() : null);
                    if (vCallRetry == null) vCallRetry = currentVideoCall;
                    if (vCallRetry != null) {
                        vCallRetry.sendSessionModifyRequest(responseProfile);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }, 500);
            staticHandler.post(() -> {
                if (MainActivity.methodChannel != null) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("isVideo", true);
                    map.put("videoState", VideoProfile.STATE_BIDIRECTIONAL);
                    map.put("remoteTextureId", MainActivity.remoteTextureId);
                    map.put("localTextureId", MainActivity.localTextureId);
                    MainActivity.methodChannel.invokeMethod("onVideoStateChanged", map);
                }
            });
        }
    }

    public static void declineVideoUpgrade() {
        InCallService.VideoCall vCall = (activeCall != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) ? activeCall.getVideoCall() : null;
        if (vCall == null) vCall = currentVideoCall;
        if (vCall != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            VideoProfile responseProfile = new VideoProfile(
                VideoProfile.STATE_AUDIO_ONLY,
                VideoProfile.QUALITY_DEFAULT
            );
            vCall.sendSessionModifyResponse(responseProfile);
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (instance == this) instance = null;
        currentVideoCall = null;
        currentRemoteSurface = null;
        currentLocalSurface = null;
    }

    private void setupVideoCall(final InCallService.VideoCall videoCall) {
        if (videoCall == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return;
        currentVideoCall = videoCall;
        if (isCallVideo(activeCall)) {
            syncVideoSession(videoCall, this, false);
        }
        try {
            videoCall.registerCallback(new InCallService.VideoCall.Callback() {
                @Override
                public void onSessionModifyRequestReceived(VideoProfile videoProfile) {
                    int videoState = videoProfile.getVideoState();
                    boolean isVideo = VideoProfile.isVideo(videoState) ||
                                      VideoProfile.isBidirectional(videoState) ||
                                      VideoProfile.isTransmissionEnabled(videoState) ||
                                      VideoProfile.isReceptionEnabled(videoState);
                    Log.d("CallvynVideo", "onSessionModifyRequestReceived: videoState=" + videoState + ", isVideo=" + isVideo);

                    final int responseState = isVideo ? VideoProfile.STATE_BIDIRECTIONAL : VideoProfile.STATE_AUDIO_ONLY;
                    VideoProfile responseProfile = new VideoProfile(
                        responseState,
                        VideoProfile.QUALITY_DEFAULT
                    );
                    if (isVideo) {
                        syncVideoSession(videoCall, CallvynInCallService.this, false);
                    }
                    videoCall.sendSessionModifyResponse(responseProfile);
                    Log.d("CallvynVideo", "sendSessionModifyResponse sent with state=" + responseState);

                    final boolean finalIsVideo = isVideo;
                    mainHandler.post(() -> {
                        if (MainActivity.methodChannel != null) {
                            Map<String, Object> map1 = new HashMap<>();
                            map1.put("isVideo", finalIsVideo);
                            map1.put("remoteTextureId", MainActivity.remoteTextureId);
                            map1.put("localTextureId", MainActivity.localTextureId);
                            MainActivity.methodChannel.invokeMethod("onVideoUpgradeRequested", map1);

                            Map<String, Object> map2 = new HashMap<>();
                            map2.put("isVideo", finalIsVideo);
                            map2.put("videoState", responseState);
                            map2.put("remoteTextureId", MainActivity.remoteTextureId);
                            map2.put("localTextureId", MainActivity.localTextureId);
                            MainActivity.methodChannel.invokeMethod("onVideoStateChanged", map2);
                        }
                    });
                }

                @Override
                public void onSessionModifyResponseReceived(int status, VideoProfile requestProfile, VideoProfile responseProfile) {
                    boolean isVideo = responseProfile != null && (
                        VideoProfile.isVideo(responseProfile.getVideoState()) ||
                        VideoProfile.isBidirectional(responseProfile.getVideoState())
                    );
                    Log.d("CallvynVideo", "onSessionModifyResponseReceived: status=" + status + ", respVideoState=" + (responseProfile != null ? responseProfile.getVideoState() : "null") + ", isVideo=" + isVideo);
                    if (isVideo) {
                        syncVideoSession(videoCall, CallvynInCallService.this, false);
                    }
                    final boolean finalIsVideo = isVideo;
                    final int finalStatus = status;
                    mainHandler.post(() -> {
                        if (MainActivity.methodChannel != null) {
                            Map<String, Object> map = new HashMap<>();
                            map.put("isVideo", finalIsVideo);
                            map.put("status", finalStatus);
                            map.put("remoteTextureId", MainActivity.remoteTextureId);
                            map.put("localTextureId", MainActivity.localTextureId);
                            MainActivity.methodChannel.invokeMethod("onVideoStateChanged", map);
                        }
                    });
                }

                @Override
                public void onCallSessionEvent(int event) {
                    Log.d("CallvynVideo", "onCallSessionEvent: event=" + event);
                    if (event == 1) {
                        syncVideoSession(videoCall, CallvynInCallService.this, false); // CAMERA_FAILURE: retry
                    } else if (event == 2) {
                        attachSurfaces(videoCall); // CAMERA_READY: attach surfaces
                    }
                }

                @Override
                public void onPeerDimensionsChanged(final int width, final int height) {
                    Log.d("CallvynVideo", "onPeerDimensionsChanged: " + width + "x" + height);
                    mainHandler.post(() -> {
                        if (MainActivity.methodChannel != null) {
                            Map<String, Object> map = new HashMap<>();
                            map.put("width", width);
                            map.put("height", height);
                            MainActivity.methodChannel.invokeMethod("onPeerDimensionsChanged", map);
                        }
                    });
                }

                @Override
                public void onVideoQualityChanged(final int videoQuality) {
                    Log.d("CallvynVideo", "onVideoQualityChanged: " + videoQuality);
                    mainHandler.post(() -> {
                        if (MainActivity.methodChannel != null) {
                            Map<String, Object> map = new HashMap<>();
                            map.put("quality", videoQuality);
                            MainActivity.methodChannel.invokeMethod("onVideoQualityChanged", map);
                        }
                    });
                }

                @Override
                public void onCallDataUsageChanged(long dataUsage) {
                    Log.d("CallvynVideo", "onCallDataUsageChanged: " + dataUsage);
                }

                @Override
                public void onCameraCapabilitiesChanged(VideoProfile.CameraCapabilities cameraCapabilities) {
                    Log.d("CallvynVideo", "onCameraCapabilitiesChanged: max " + cameraCapabilities.getWidth() + "x" + cameraCapabilities.getHeight());
                }
            });
        } catch (Exception e) {
            Log.e("CallvynVideo", "registerCallback error: " + e.getMessage(), e);
        }
    }

    private String lookupContactName(String phoneNumber) {
        if (phoneNumber == null || phoneNumber.isEmpty()) return "";
        try {
            Uri uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(phoneNumber)
            );
            String[] projection = new String[]{ContactsContract.PhoneLookup.DISPLAY_NAME};
            try (Cursor cursor = getContentResolver().query(uri, projection, null, null, null)) {
                if (cursor != null && cursor.moveToFirst()) {
                    int nameIdx = cursor.getColumnIndex(ContactsContract.PhoneLookup.DISPLAY_NAME);
                    if (nameIdx >= 0) {
                        String name = cursor.getString(nameIdx);
                        if (name != null && !name.isEmpty()) {
                            return name;
                        }
                    }
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return "";
    }

    @Override
    public void onCallAdded(final Call call) {
        super.onCallAdded(call);
        activeCall = call;
        final boolean isVideo = isCallVideo(call);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            currentVideoCall = call.getVideoCall();
            if (call.getVideoCall() != null) {
                setupVideoCall(call.getVideoCall());
            }
        }
        final String number = (call.getDetails() != null && call.getDetails().getHandle() != null)
                ? call.getDetails().getHandle().getSchemeSpecificPart() : "";
        String callerName = call.getDetails() != null ? call.getDetails().getCallerDisplayName() : "";
        if (callerName == null || callerName.isEmpty()) {
            callerName = lookupContactName(number);
        }
        final String finalCallerName = callerName != null ? callerName : "";

        int simSlot = 1;
        try {
            PhoneAccountHandle handle = call.getDetails() != null ? call.getDetails().getAccountHandle() : null;
            String id = handle != null ? handle.getId() : "";
            if (id != null && (id.contains("1") || id.contains("sub_2") || id.contains("slot_1"))) {
                simSlot = 2;
            }
        } catch (Exception ignored) {}
        final int finalSimSlot = simSlot;

        String stateName;
        switch (call.getState()) {
            case Call.STATE_RINGING:
                stateName = "RINGING";
                break;
            case Call.STATE_ACTIVE:
                stateName = "ACTIVE";
                break;
            case Call.STATE_DIALING:
                stateName = "DIALING";
                break;
            case Call.STATE_HOLDING:
                stateName = "HOLDING";
                break;
            case Call.STATE_DISCONNECTED:
                stateName = "DISCONNECTED";
                break;
            default:
                stateName = "CONNECTING";
                break;
        }
        final String finalStateName = stateName;

        if (call.getState() == Call.STATE_RINGING) {
            showIncomingCallUI(number, finalCallerName, isVideo);
        }

        mainHandler.post(() -> {
            if (MainActivity.methodChannel != null) {
                Map<String, Object> map = new HashMap<>();
                map.put("state", finalStateName);
                map.put("number", number);
                map.put("name", finalCallerName);
                map.put("simSlot", finalSimSlot);
                map.put("isVideo", isVideo);
                map.put("remoteTextureId", MainActivity.remoteTextureId);
                map.put("localTextureId", MainActivity.localTextureId);
                MainActivity.methodChannel.invokeMethod("onCallStateChanged", map);
            }
        });

        call.registerCallback(new Call.Callback() {
            @Override
            public void onVideoCallChanged(Call call, InCallService.VideoCall videoCall) {
                super.onVideoCallChanged(call, videoCall);
                setupVideoCall(videoCall);
            }

            @Override
            public void onDetailsChanged(Call call, Call.Details details) {
                super.onDetailsChanged(call, details);
                final boolean isCallVid = isCallVideo(call);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && call.getVideoCall() != null) {
                    setupVideoCall(call.getVideoCall());
                }
                mainHandler.post(() -> {
                    if (MainActivity.methodChannel != null) {
                        Map<String, Object> map = new HashMap<>();
                        map.put("isVideo", isCallVid);
                        map.put("remoteTextureId", MainActivity.remoteTextureId);
                        map.put("localTextureId", MainActivity.localTextureId);
                        MainActivity.methodChannel.invokeMethod("onVideoStateChanged", map);
                    }
                });
            }

            @Override
            public void onConnectionEvent(Call call, String event, Bundle extras) {
                super.onConnectionEvent(call, event, extras);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && call.getVideoCall() != null) {
                    setupVideoCall(call.getVideoCall());
                }
            }

            @Override
            public void onStateChanged(Call call, int state) {
                super.onStateChanged(call, state);
                final boolean isCallVid = isCallVideo(call);
                String sName;
                switch (state) {
                    case Call.STATE_ACTIVE:
                        sName = "ACTIVE";
                        break;
                    case Call.STATE_DIALING:
                        sName = "DIALING";
                        break;
                    case Call.STATE_RINGING:
                        sName = "RINGING";
                        break;
                    case Call.STATE_DISCONNECTED:
                        sName = "DISCONNECTED";
                        break;
                    case Call.STATE_HOLDING:
                        sName = "HOLDING";
                        break;
                    default:
                        sName = "CONNECTING";
                        break;
                }
                final String finalSName = sName;

                String currentNum = (call.getDetails() != null && call.getDetails().getHandle() != null)
                        ? call.getDetails().getHandle().getSchemeSpecificPart() : "";
                String currentName = call.getDetails() != null ? call.getDetails().getCallerDisplayName() : "";
                if (currentName == null || currentName.isEmpty()) {
                    currentName = lookupContactName(currentNum);
                }
                final String finalCurrentNum = currentNum != null ? currentNum : "";
                final String finalCurrentName = currentName != null ? currentName : "";

                if (state == Call.STATE_RINGING) {
                    showIncomingCallUI(finalCurrentNum, finalCurrentName, isCallVid);
                } else if (state == Call.STATE_ACTIVE) {
                    dismissIncomingCallNotification();
                    removeFloatingOverlay();
                    if (callConnectTimeMs == 0L) {
                        callConnectTimeMs = System.currentTimeMillis();
                    }
                    if (!MainActivity.isAppInForeground) {
                        showOngoingCallNotification();
                    }
                } else if (state == Call.STATE_HOLDING) {
                    if (!MainActivity.isAppInForeground) {
                        updateOngoingCallNotification();
                    }
                } else if (state == Call.STATE_DISCONNECTED) {
                    dismissIncomingCallNotification();
                    dismissOngoingCallNotification();
                    stopOngoingTimer();
                    removeFloatingOverlay();
                    callConnectTimeMs = 0L;
                }

                mainHandler.post(() -> {
                    if (MainActivity.methodChannel != null) {
                        Map<String, Object> map = new HashMap<>();
                        map.put("state", finalSName);
                        map.put("number", finalCurrentNum);
                        map.put("name", finalCurrentName);
                        map.put("simSlot", finalSimSlot);
                        map.put("isVideo", isCallVid);
                        map.put("remoteTextureId", MainActivity.remoteTextureId);
                        map.put("localTextureId", MainActivity.localTextureId);
                        MainActivity.methodChannel.invokeMethod("onCallStateChanged", map);
                    }
                });

                if (state == Call.STATE_DISCONNECTED) {
                    activeCall = null;
                    currentVideoCall = null;
                }
            }
        });
    }

    @Override
    public void onCallRemoved(Call call) {
        super.onCallRemoved(call);
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (call.getVideoCall() != null) {
                    call.getVideoCall().setCamera(null);
                }
                if (currentVideoCall != null) {
                    currentVideoCall.setCamera(null);
                }
            }
        } catch (Exception ignored) {}
        activeCall = null;
        currentVideoCall = null;
        currentRemoteSurface = null;
        currentLocalSurface = null;
        lastSelectedCameraId = null;
        callConnectTimeMs = 0L;
        stopOngoingTimer();
        dismissIncomingCallNotification();
        dismissOngoingCallNotification();
        removeFloatingOverlay();
        if (MainActivity.wasLaunchedByIncoming) {
            MainActivity.wasLaunchedByIncoming = false;
            mainHandler.post(() -> {
                try {
                    if (MainActivity.instance != null) {
                        MainActivity.instance.moveTaskToBack(true);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            });
        }
        mainHandler.post(() -> {
            if (MainActivity.methodChannel != null) {
                Map<String, Object> map = new HashMap<>();
                map.put("state", "DISCONNECTED");
                MainActivity.methodChannel.invokeMethod("onCallStateChanged", map);
            }
        });
    }

    private Set<String> getLauncherPackages(Context context) {
        Set<String> launcherPackages = new HashSet<>();
        try {
            Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
            List<ResolveInfo> resolveInfos = context.getPackageManager().queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY);
            for (ResolveInfo info : resolveInfos) {
                if (info.activityInfo != null && info.activityInfo.packageName != null) {
                    launcherPackages.add(info.activityInfo.packageName);
                }
            }
            ResolveInfo defaultResolve = context.getPackageManager().resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY);
            if (defaultResolve != null && defaultResolve.activityInfo != null && defaultResolve.activityInfo.packageName != null) {
                launcherPackages.add(defaultResolve.activityInfo.packageName);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        launcherPackages.addAll(Arrays.asList(
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.google.android.launcher",
            "com.miui.home",
            "com.mi.android.globallauncher",
            "com.sec.android.app.launcher",
            "com.huawei.android.launcher",
            "com.oppo.launcher",
            "com.coloros.launcher",
            "com.oneplus.launcher",
            "com.transsion.launcher",
            "com.realme.launcher",
            "com.nothing.launcher",
            "com.motorola.launcher3",
            "com.teslacoilsw.launcher",
            "com.actionlauncher.playStore",
            "com.microsoft.launcher"
        ));
        return launcherPackages;
    }

    private boolean isLauncherOrDialerFocused(Context context) {
        try {
            if (MainActivity.isAppInForeground) {
                return true;
            }

            Set<String> launcherPackages = getLauncherPackages(context);

            try {
                UsageStatsManager usm = (UsageStatsManager) context.getSystemService(Context.USAGE_STATS_SERVICE);
                if (usm != null) {
                    long endTime = System.currentTimeMillis();
                    long beginTime = endTime - 10000;
                    UsageEvents events = usm.queryEvents(beginTime, endTime);
                    String lastTopPackage = null;
                    long lastTimestamp = 0;
                    UsageEvents.Event event = new UsageEvents.Event();
                    while (events != null && events.hasNextEvent()) {
                        events.getNextEvent(event);
                        int type = event.getEventType();
                        if (type == UsageEvents.Event.ACTIVITY_RESUMED ||
                            type == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                            if (event.getTimeStamp() >= lastTimestamp) {
                                lastTimestamp = event.getTimeStamp();
                                lastTopPackage = event.getPackageName();
                            }
                        }
                    }
                    if (lastTopPackage != null) {
                        if (launcherPackages.contains(lastTopPackage) || lastTopPackage.equals(context.getPackageName())) {
                            return true;
                        } else if (!"android".equals(lastTopPackage) && !"com.android.systemui".equals(lastTopPackage)) {
                            return false;
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }

            try {
                ActivityManager am = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
                @SuppressWarnings("deprecation")
                List<ActivityManager.RunningTaskInfo> tasks = am != null ? am.getRunningTasks(5) : null;
                if (tasks != null && !tasks.isEmpty()) {
                    for (ActivityManager.RunningTaskInfo task : tasks) {
                        String topPkg = null;
                        if (task.topActivity != null) topPkg = task.topActivity.getPackageName();
                        else if (task.baseActivity != null) topPkg = task.baseActivity.getPackageName();
                        if (topPkg != null) {
                            if (launcherPackages.contains(topPkg) || topPkg.equals(context.getPackageName())) {
                                return true;
                            } else if (!"android".equals(topPkg) && !"com.android.systemui".equals(topPkg)) {
                                return false;
                            }
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }

            try {
                ActivityManager am = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
                List<ActivityManager.RunningAppProcessInfo> processes = am != null ? am.getRunningAppProcesses() : null;
                if (processes != null && !processes.isEmpty()) {
                    boolean foundLauncherForeground = false;
                    boolean foundOtherForeground = false;

                    for (ActivityManager.RunningAppProcessInfo proc : processes) {
                        if (proc.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND) {
                            String[] pkgList = proc.pkgList != null ? proc.pkgList : new String[0];
                            for (String pkg : pkgList) {
                                if (pkg.equals(context.getPackageName()) || launcherPackages.contains(pkg)) {
                                    foundLauncherForeground = true;
                                } else if (!"android".equals(pkg) && !"com.android.systemui".equals(pkg)) {
                                    foundOtherForeground = true;
                                }
                            }
                        }
                    }

                    if (foundLauncherForeground && !foundOtherForeground) {
                        return true;
                    }
                    if (foundOtherForeground) {
                        return false;
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }

            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    private void showFloatingOverlay(final String number) {
        mainHandler.post(() -> {
            try {
                if (overlayView != null) return;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(CallvynInCallService.this)) {
                    return;
                }
                windowManager = (WindowManager) getSystemService(Context.WINDOW_SERVICE);
                LayoutInflater inflater = (LayoutInflater) getSystemService(Context.LAYOUT_INFLATER_SERVICE);
                if (inflater == null) return;
                View view = inflater.inflate(R.layout.notification_incoming_call_headsup, null);
                if (view == null) return;

                WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                        ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                        : WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN |
                            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
                    PixelFormat.TRANSLUCENT
                );
                params.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
                params.y = 20;

                TextView tvName = view.findViewById(R.id.tv_caller_name);
                if (tvName != null) {
                    tvName.setText(number != null && !number.isEmpty() ? number : "Unknown Caller");
                }
                TextView tvNumber = view.findViewById(R.id.tv_caller_number);
                if (tvNumber != null) {
                    tvNumber.setText("Incoming Call");
                }

                View btnReject = view.findViewById(R.id.btn_reject_call);
                if (btnReject != null) {
                    btnReject.setOnClickListener(v -> {
                        removeFloatingOverlay();
                        dismissIncomingCallNotification();
                        try {
                            Call active = activeCall;
                            if (active != null) {
                                if (active.getState() == Call.STATE_RINGING) {
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                        active.reject(false, null);
                                    } else {
                                        active.disconnect();
                                    }
                                } else {
                                    active.disconnect();
                                }
                            }
                        } catch (Exception e) {
                            e.printStackTrace();
                        }
                    });
                }

                View btnAnswer = view.findViewById(R.id.btn_answer_call);
                if (btnAnswer != null) {
                    btnAnswer.setOnClickListener(v -> {
                        removeFloatingOverlay();
                        dismissIncomingCallNotification();
                        answerCall(false);
                        Intent fullScreenIntent = new Intent(CallvynInCallService.this, MainActivity.class);
                        fullScreenIntent.setAction(Intent.ACTION_MAIN);
                        fullScreenIntent.addCategory(Intent.CATEGORY_LAUNCHER);
                        fullScreenIntent.addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK |
                            Intent.FLAG_ACTIVITY_CLEAR_TOP |
                            Intent.FLAG_ACTIVITY_SINGLE_TOP |
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                        );
                        fullScreenIntent.putExtra("incoming_number", number);
                        fullScreenIntent.putExtra("is_incoming", true);
                        startActivity(fullScreenIntent);
                    });
                }

                View cardContainer = view.findViewById(R.id.headsup_card_container);
                if (cardContainer != null) {
                    cardContainer.setOnClickListener(v -> {
                        removeFloatingOverlay();
                        Intent fullScreenIntent = new Intent(CallvynInCallService.this, MainActivity.class);
                        fullScreenIntent.setAction(Intent.ACTION_MAIN);
                        fullScreenIntent.addCategory(Intent.CATEGORY_LAUNCHER);
                        fullScreenIntent.addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK |
                            Intent.FLAG_ACTIVITY_CLEAR_TOP |
                            Intent.FLAG_ACTIVITY_SINGLE_TOP |
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                        );
                        fullScreenIntent.putExtra("incoming_number", number);
                        fullScreenIntent.putExtra("is_incoming", true);
                        startActivity(fullScreenIntent);
                    });
                }

                if (windowManager != null) {
                    windowManager.addView(view, params);
                    overlayView = view;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
    }

    private void removeFloatingOverlay() {
        mainHandler.post(() -> {
            try {
                if (overlayView != null && windowManager != null) {
                    windowManager.removeView(overlayView);
                    overlayView = null;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
    }

    private void createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel incomingChannel = new NotificationChannel(
                CHANNEL_INCOMING_ID,
                "Incoming Calls",
                NotificationManager.IMPORTANCE_HIGH
            );
            incomingChannel.setDescription("Incoming call alert");
            incomingChannel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            incomingChannel.setSound(null, null);
            incomingChannel.enableVibration(true);

            NotificationChannel ongoingChannel = new NotificationChannel(
                CHANNEL_ONGOING_ID,
                "Ongoing Calls",
                NotificationManager.IMPORTANCE_LOW
            );
            ongoingChannel.setDescription("Active call in background");
            ongoingChannel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            ongoingChannel.setShowBadge(false);
            ongoingChannel.setSound(null, null);

            NotificationManager notificationManager = getSystemService(NotificationManager.class);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(incomingChannel);
                notificationManager.createNotificationChannel(ongoingChannel);
            }
        }
    }

    private Bitmap createAvatarBitmap(String name, String number) {
        int size = 128;
        Bitmap bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);

        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        String initial = "?";
        if (name != null && !name.trim().isEmpty()) {
            initial = String.valueOf(name.trim().charAt(0)).toUpperCase(Locale.US);
        } else if (number != null && !number.trim().isEmpty()) {
            initial = String.valueOf(number.trim().charAt(0));
        }

        int[] colors = new int[]{
            0xFF007AFF, 0xFF34C759, 0xFF5856D6,
            0xFFFF9500, 0xFFAF52DE, 0xFF00C7BE
        };
        String hashKey = (name != null && !name.isEmpty()) ? name : (number != null ? number : "");
        int colorIndex = Math.abs(hashKey.hashCode()) % colors.length;
        paint.setColor(colors[colorIndex]);

        RectF rectF = new RectF(0f, 0f, (float) size, (float) size);
        canvas.drawRoundRect(rectF, 32f, 32f, paint);

        paint.setColor(Color.WHITE);
        paint.setTextSize(56f);
        paint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        paint.setTextAlign(Paint.Align.CENTER);

        Rect textBounds = new Rect();
        paint.getTextBounds(initial, 0, initial.length(), textBounds);
        float y = (size / 2f) + (textBounds.height() / 2f) - textBounds.bottom;
        canvas.drawText(initial, size / 2f, y, paint);

        return bitmap;
    }

    private void showIncomingCallUI(String number, String name, boolean isVideo) {
        try {
            KeyguardManager keyguardManager = (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);
            PowerManager powerManager = (PowerManager) getSystemService(Context.POWER_SERVICE);

            boolean isLocked = keyguardManager != null ? keyguardManager.isKeyguardLocked() : true;
            boolean isInteractive = powerManager != null && powerManager.isInteractive();
            boolean isLauncherOrDialer = isLauncherOrDialerFocused(this);

            if (!isInteractive && powerManager != null) {
                PowerManager.WakeLock wakeLock = powerManager.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP | PowerManager.ON_AFTER_RELEASE,
                    "Callvyn:IncomingCallLockScreen"
                );
                wakeLock.acquire(30000);
            }

            createNotificationChannels();

            Intent fullScreenIntent = new Intent(this, MainActivity.class);
            fullScreenIntent.setAction(Intent.ACTION_MAIN);
            fullScreenIntent.addCategory(Intent.CATEGORY_LAUNCHER);
            fullScreenIntent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK |
                Intent.FLAG_ACTIVITY_CLEAR_TOP |
                Intent.FLAG_ACTIVITY_SINGLE_TOP |
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            );
            fullScreenIntent.putExtra("incoming_number", number);
            fullScreenIntent.putExtra("caller_name", name);
            fullScreenIntent.putExtra("is_incoming", true);
            fullScreenIntent.putExtra("is_video_call", isVideo);

            // 1. CONDITION 1: If Phone is Locked OR Launcher/Dialer is focused -> Full Screen UI ONLY (NO notification)
            if (isLocked || isLauncherOrDialer) {
                dismissIncomingCallNotification();
                try {
                    startActivity(fullScreenIntent);
                } catch (Exception e) {
                    e.printStackTrace();
                }
                return;
            }

            // 2. CONDITION 2: If User is in another app -> Show Notification with action buttons
            String timeStr = new SimpleDateFormat("h:mm a", Locale.getDefault()).format(new Date()).toLowerCase(Locale.getDefault());
            String displayName = (name != null && !name.isEmpty()) ? name : ((number != null && !number.isEmpty()) ? number : "Unknown Caller");
            String headerText = displayName + " • Callvyn • " + timeStr;
            String subtitleText = "Incoming call • " + number;

            Bitmap avatarBitmap = createAvatarBitmap(displayName, number);

            PendingIntent contentPendingIntent = PendingIntent.getActivity(
                this,
                1002,
                fullScreenIntent,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                    ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
                    : PendingIntent.FLAG_UPDATE_CURRENT
            );

            Intent rejectIntent = new Intent(this, CallActionReceiver.class);
            rejectIntent.setAction(CallActionReceiver.ACTION_REJECT);
            PendingIntent rejectPendingIntent = PendingIntent.getBroadcast(
                this,
                1003,
                rejectIntent,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                    ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
                    : PendingIntent.FLAG_UPDATE_CURRENT
            );

            Intent answerIntent = new Intent(this, CallActionReceiver.class);
            answerIntent.setAction(CallActionReceiver.ACTION_ANSWER);
            PendingIntent answerPendingIntent = PendingIntent.getBroadcast(
                this,
                1004,
                answerIntent,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                    ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
                    : PendingIntent.FLAG_UPDATE_CURRENT
            );

            RemoteViews customCardView = new RemoteViews(getPackageName(), R.layout.notification_incoming_call);
            customCardView.setImageViewBitmap(R.id.iv_caller_avatar, avatarBitmap);
            customCardView.setImageViewResource(R.id.iv_badge_icon, R.drawable.ic_notification);
            customCardView.setTextViewText(R.id.tv_header_title, headerText);
            customCardView.setTextViewText(R.id.tv_subtitle, subtitleText);
            customCardView.setOnClickPendingIntent(R.id.btn_reject_call, rejectPendingIntent);
            customCardView.setOnClickPendingIntent(R.id.btn_answer_call, answerPendingIntent);
            customCardView.setOnClickPendingIntent(R.id.notification_incoming_container, contentPendingIntent);

            NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(this, CHANNEL_INCOMING_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setColor(0xFF02BC58)
                .setContentTitle(displayName)
                .setContentText(subtitleText)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setContentIntent(contentPendingIntent)
                .setCustomContentView(customCardView)
                .setCustomHeadsUpContentView(customCardView)
                .setCustomBigContentView(customCardView)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setOngoing(true);

            NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (notificationManager != null) {
                notificationManager.notify(NOTIFICATION_INCOMING_ID, notificationBuilder.build());
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void showOngoingCallNotification() {
        if (MainActivity.isAppInForeground) {
            dismissOngoingCallNotification();
            return;
        }
        Call call = activeCall;
        if (call == null) return;
        String currentNum = (call.getDetails() != null && call.getDetails().getHandle() != null)
                ? call.getDetails().getHandle().getSchemeSpecificPart() : "";
        String currentName = call.getDetails() != null ? call.getDetails().getCallerDisplayName() : "";
        if (currentName == null || currentName.isEmpty()) {
            currentName = lookupContactName(currentNum);
        }

        createNotificationChannels();

        String timeStr = new SimpleDateFormat("h:mm a", Locale.getDefault()).format(new Date()).toLowerCase(Locale.getDefault());
        String displayName = (currentName != null && !currentName.isEmpty()) ? currentName : ((currentNum != null && !currentNum.isEmpty()) ? currentNum : "Unknown Caller");
        String headerText = displayName + " • Callvyn • " + timeStr;

        boolean isHolding = call.getState() == Call.STATE_HOLDING;
        long durationSecs = callConnectTimeMs > 0 ? (System.currentTimeMillis() - callConnectTimeMs) / 1000 : 0;
        String durationFormatted = String.format(Locale.getDefault(), "%02d:%02d", durationSecs / 60, durationSecs % 60);
        String subtitleText = isHolding ? ("Call on hold • " + durationFormatted) : ("Ongoing call • " + durationFormatted);

        Bitmap avatarBitmap = createAvatarBitmap(displayName, currentNum);

        Intent fullScreenIntent = new Intent(this, MainActivity.class);
        fullScreenIntent.setAction(Intent.ACTION_MAIN);
        fullScreenIntent.addCategory(Intent.CATEGORY_LAUNCHER);
        fullScreenIntent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK |
            Intent.FLAG_ACTIVITY_CLEAR_TOP |
            Intent.FLAG_ACTIVITY_SINGLE_TOP |
            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        );

        PendingIntent contentPendingIntent = PendingIntent.getActivity(
            this,
            1005,
            fullScreenIntent,
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
                : PendingIntent.FLAG_UPDATE_CURRENT
        );

        Intent endCallIntent = new Intent(this, CallActionReceiver.class);
        endCallIntent.setAction(CallActionReceiver.ACTION_END_CALL);
        PendingIntent endCallPendingIntent = PendingIntent.getBroadcast(
            this,
            1006,
            endCallIntent,
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
                : PendingIntent.FLAG_UPDATE_CURRENT
        );

        Intent holdIntent = new Intent(this, CallActionReceiver.class);
        holdIntent.setAction(CallActionReceiver.ACTION_TOGGLE_HOLD);
        PendingIntent holdPendingIntent = PendingIntent.getBroadcast(
            this,
            1007,
            holdIntent,
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
                : PendingIntent.FLAG_UPDATE_CURRENT
        );

        Intent speakerIntent = new Intent(this, CallActionReceiver.class);
        speakerIntent.setAction(CallActionReceiver.ACTION_TOGGLE_SPEAKER);
        PendingIntent speakerPendingIntent = PendingIntent.getBroadcast(
            this,
            1008,
            speakerIntent,
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
                : PendingIntent.FLAG_UPDATE_CURRENT
        );

        RemoteViews customCardView = new RemoteViews(getPackageName(), R.layout.notification_ongoing_call);
        customCardView.setImageViewBitmap(R.id.iv_caller_avatar, avatarBitmap);
        customCardView.setImageViewResource(R.id.iv_badge_icon, R.drawable.ic_notification);
        customCardView.setTextViewText(R.id.tv_header_title, headerText);
        customCardView.setTextViewText(R.id.tv_subtitle, subtitleText);

        if (isHolding) {
            customCardView.setInt(R.id.btn_hold_call, "setBackgroundResource", R.drawable.bg_btn_action_circle_active);
        } else {
            customCardView.setInt(R.id.btn_hold_call, "setBackgroundResource", R.drawable.bg_btn_action_circle);
        }

        boolean isSpeaker = isSpeakerOn();
        if (isSpeaker) {
            customCardView.setInt(R.id.btn_speaker_call, "setBackgroundResource", R.drawable.bg_btn_action_circle_active);
        } else {
            customCardView.setInt(R.id.btn_speaker_call, "setBackgroundResource", R.drawable.bg_btn_action_circle);
        }

        customCardView.setOnClickPendingIntent(R.id.btn_end_call, endCallPendingIntent);
        customCardView.setOnClickPendingIntent(R.id.btn_hold_call, holdPendingIntent);
        customCardView.setOnClickPendingIntent(R.id.btn_speaker_call, speakerPendingIntent);
        customCardView.setOnClickPendingIntent(R.id.notification_ongoing_container, contentPendingIntent);

        NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(this, CHANNEL_ONGOING_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFF02BC58)
            .setContentTitle(displayName)
            .setContentText(subtitleText)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setContentIntent(contentPendingIntent)
            .setCustomContentView(customCardView)
            .setCustomBigContentView(customCardView)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false);

        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (notificationManager != null) {
            notificationManager.notify(NOTIFICATION_ONGOING_ID, notificationBuilder.build());
        }

        startOngoingTimer();
    }

    public void updateOngoingCallNotification() {
        if (!MainActivity.isAppInForeground && activeCall != null) {
            int state = activeCall.getState();
            if (state == Call.STATE_ACTIVE || state == Call.STATE_HOLDING) {
                showOngoingCallNotification();
            }
        }
    }

    private void startOngoingTimer() {
        stopOngoingTimer();
        ongoingTimerRunnable = new Runnable() {
            @Override
            public void run() {
                if (!MainActivity.isAppInForeground && activeCall != null &&
                    (activeCall.getState() == Call.STATE_ACTIVE || activeCall.getState() == Call.STATE_HOLDING)) {
                    showOngoingCallNotification();
                    mainHandler.postDelayed(this, 1000);
                } else {
                    stopOngoingTimer();
                }
            }
        };
        mainHandler.postDelayed(ongoingTimerRunnable, 1000);
    }

    private void stopOngoingTimer() {
        if (ongoingTimerRunnable != null) {
            mainHandler.removeCallbacks(ongoingTimerRunnable);
            ongoingTimerRunnable = null;
        }
    }

    public void dismissIncomingCallNotification() {
        try {
            NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (notificationManager != null) {
                notificationManager.cancel(NOTIFICATION_INCOMING_ID);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void dismissOngoingCallNotification() {
        try {
            stopOngoingTimer();
            NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (notificationManager != null) {
                notificationManager.cancel(NOTIFICATION_ONGOING_ID);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public boolean isSpeakerOn() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && getCallAudioState() != null) {
            return getCallAudioState().getRoute() == CallAudioState.ROUTE_SPEAKER;
        }
        return false;
    }

    public void setCallMuted(boolean muted) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                setMuted(muted);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void setCallSpeaker(boolean enabled) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                setAudioRoute(enabled ? CallAudioState.ROUTE_SPEAKER : CallAudioState.ROUTE_EARPIECE);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
