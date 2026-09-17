package com.sonoou.callvyndialer;

import android.Manifest;
import android.app.KeyguardManager;
import android.app.WallpaperManager;
import android.app.role.RoleManager;
import android.content.ClipData;
import android.content.ClipDescription;
import android.content.ClipboardManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ShortcutInfo;
import android.content.pm.ShortcutManager;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.Icon;
import android.media.AudioDeviceInfo;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioRecord;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.MediaPlayer;
import android.media.MediaRecorder;
import android.media.RingtoneManager;
import android.media.audiofx.AcousticEchoCanceler;
import android.media.audiofx.AutomaticGainControl;
import android.media.audiofx.NoiseSuppressor;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.PersistableBundle;
import android.os.PowerManager;
import android.provider.CallLog;
import android.provider.ContactsContract;
import android.provider.MediaStore;
import android.provider.Settings;
import android.provider.Telephony;
import android.telecom.Call;
import android.telecom.PhoneAccountHandle;
import android.telecom.TelecomManager;
import android.telecom.VideoProfile;
import android.telephony.PhoneStateListener;
import android.telephony.SubscriptionInfo;
import android.telephony.SubscriptionManager;
import android.telephony.TelephonyCallback;
import android.telephony.TelephonyManager;
import android.view.Surface;
import android.view.WindowManager;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.TextureRegistry;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.sonoou.callvyndialer/sim";

    public static MainActivity instance;
    public static MethodChannel methodChannel;
    public static boolean isAppInForeground = false;
    public static boolean wasLaunchedByIncoming = false;
    public static TextureRegistry.SurfaceTextureEntry remoteTextureEntry;
    public static TextureRegistry.SurfaceTextureEntry localTextureEntry;
    public static Surface remoteSurface;
    public static Surface localSurface;
    public static Long remoteTextureId;
    public static Long localTextureId;

    private MediaRecorder mediaRecorder;
    private CallAudioRecorder callAudioRecorder;
    private String currentRecordingPath;
    private MediaPlayer previewMediaPlayer;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // IMPORTANT: extract the pending dial number BEFORE super.onCreate(), because
        // FlutterActivity's super.onCreate() internally calls configureFlutterEngine(),
        // which is where deliverPendingDialNumberIfAny() actually sends it to Dart.
        // If we extract it after super.onCreate(), configureFlutterEngine() has already
        // run and delivery never happens on cold start.
        pendingDialNumber = extractDialNumberFromIntent(getIntent());
        super.onCreate(savedInstanceState);
        instance = this;
        CallvynLogger.init(this);
        if (getIntent() != null && getIntent().getBooleanExtra("is_incoming", false)) {
            wasLaunchedByIncoming = true;
        }
        configureLockScreenFlags();
        CallvynForegroundService.start(this);
        cleanupPhoneAccounts();
    }

    // Holds a number extracted from an external ACTION_DIAL / ACTION_VIEW (tel:) intent
    // until the Flutter MethodChannel is ready to receive it.
    private String pendingDialNumber = null;

    /**
     * Extracts a phone number from tel: intents sent by other apps or the system
     * (e.g. clicking a "tel:+911234567890" link, or another app launching the dialer
     * with ACTION_DIAL / ACTION_VIEW). Returns null if the intent carries no such number.
     */
    private String extractDialNumberFromIntent(Intent intent) {
        if (intent == null) return null;
        String action = intent.getAction();
        android.util.Log.d("CallvynDial", "extractDialNumberFromIntent: action=" + action + ", data=" + intent.getData());
        if (!Intent.ACTION_DIAL.equals(action) && !Intent.ACTION_VIEW.equals(action)) {
            return null;
        }
        Uri data = intent.getData();
        if (data == null) return null;
        String scheme = data.getScheme();
        if (scheme == null || !(scheme.equals("tel") || scheme.equals("voicemail"))) {
            return null;
        }
        String number = data.getSchemeSpecificPart();
        if (number == null) return null;
        // Strip any query params some apps append after the number.
        int q = number.indexOf('?');
        if (q >= 0) number = number.substring(0, q);
        String result = Uri.decode(number).trim();
        android.util.Log.d("CallvynDial", "extractDialNumberFromIntent: extracted number=" + result);
        return result;
    }

    /**
     * Sends a pending external dial number to Flutter once the MethodChannel is attached.
     * Called from configureFlutterEngine after methodChannel is set, and from onNewIntent.
     */
    private void deliverPendingDialNumberIfAny() {
        android.util.Log.d("CallvynDial", "deliverPendingDialNumberIfAny: pendingDialNumber=" + pendingDialNumber + ", methodChannel=" + (methodChannel != null));
        if (pendingDialNumber != null && !pendingDialNumber.isEmpty() && methodChannel != null) {
            Map<String, Object> map = new HashMap<>();
            map.put("number", pendingDialNumber);
            methodChannel.invokeMethod("onExternalNumberReceived", map);
            android.util.Log.d("CallvynDial", "deliverPendingDialNumberIfAny: sent onExternalNumberReceived with number=" + pendingDialNumber);
            pendingDialNumber = null;
        }
    }

    private void cleanupPhoneAccounts() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                TelecomManager telecomManager = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
                ComponentName componentName = new ComponentName(this, CallvynInCallService.class);
                PhoneAccountHandle handle = new PhoneAccountHandle(componentName, "CallvynAccount");
                if (telecomManager != null) {
                    telecomManager.unregisterPhoneAccount(handle);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        isAppInForeground = true;
        configureLockScreenFlags();
        // Safety net: if a tel: number was pending before the MethodChannel/Dart
        // listener was fully ready, retry delivery here.
        deliverPendingDialNumberIfAny();
        if (CallvynInCallService.instance != null) {
            CallvynInCallService.instance.dismissOngoingCallNotification();
            CallvynInCallService.instance.dismissIncomingCallNotification();
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        isAppInForeground = false;
        Call activeCall = CallvynInCallService.activeCall;
        if (activeCall != null && (activeCall.getState() == Call.STATE_ACTIVE || activeCall.getState() == Call.STATE_HOLDING)) {
            if (CallvynInCallService.instance != null) {
                CallvynInCallService.instance.showOngoingCallNotification();
            }
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        isAppInForeground = false;
        Call activeCall = CallvynInCallService.activeCall;
        if (activeCall != null && (activeCall.getState() == Call.STATE_ACTIVE || activeCall.getState() == Call.STATE_HOLDING)) {
            if (CallvynInCallService.instance != null) {
                CallvynInCallService.instance.showOngoingCallNotification();
            }
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        isAppInForeground = false;
        try {
            if (remoteSurface != null) {
                remoteSurface.release();
                remoteSurface = null;
            }
            if (remoteTextureEntry != null) {
                remoteTextureEntry.release();
                remoteTextureEntry = null;
            }
            if (localSurface != null) {
                localSurface.release();
                localSurface = null;
            }
            if (localTextureEntry != null) {
                localTextureEntry.release();
                localTextureEntry = null;
            }
            remoteTextureId = null;
            localTextureId = null;
        } catch (Exception e) {
            e.printStackTrace();
        }
        if (instance == this) {
            instance = null;
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
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);

        String dialNumber = extractDialNumberFromIntent(intent);
        if (dialNumber != null && !dialNumber.isEmpty()) {
            pendingDialNumber = dialNumber;
            deliverPendingDialNumberIfAny();
        }

        if (intent.getBooleanExtra("is_incoming", false)) {
            wasLaunchedByIncoming = true;
            String incomingNum = intent.getStringExtra("incoming_number") != null ? intent.getStringExtra("incoming_number") : "";
            boolean isVideo = intent.getBooleanExtra("is_video_call", false) || CallvynInCallService.isCallVideo(CallvynInCallService.activeCall);
            String callerName = intent.getStringExtra("caller_name") != null ? intent.getStringExtra("caller_name") : "";
            if (callerName.isEmpty()) {
                callerName = lookupContactName(incomingNum);
            }
            if (methodChannel != null) {
                Map<String, Object> map = new HashMap<>();
                map.put("state", "RINGING");
                map.put("number", incomingNum);
                map.put("name", callerName);
                map.put("isVideo", isVideo);
                map.put("remoteTextureId", remoteTextureId);
                map.put("localTextureId", localTextureId);
                methodChannel.invokeMethod("onCallStateChanged", map);
            }
        }
        configureLockScreenFlags();
    }

    private void configureLockScreenFlags() {
        try {
            boolean isRinging = (CallvynInCallService.activeCall != null && CallvynInCallService.activeCall.getState() == Call.STATE_RINGING) || wasLaunchedByIncoming;
            if (isRinging) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    setShowWhenLocked(true);
                    setTurnScreenOn(true);
                    KeyguardManager keyguardManager = (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);
                    if (keyguardManager != null) {
                        keyguardManager.requestDismissKeyguard(this, null);
                    }
                } else {
                    @SuppressWarnings("deprecation")
                    int flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED |
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD |
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON;
                    getWindow().addFlags(flags);
                }
                getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        flutterEngine.getPlugins().add(new VideoCallPlugin());
        flutterEngine.getPlatformViewsController().getRegistry().registerViewFactory("com.callvyn.video/remote_view", new CallvynVideoView.CallvynRemoteVideoViewFactory());
        flutterEngine.getPlatformViewsController().getRegistry().registerViewFactory("com.callvyn.video/local_view", new CallvynVideoView.CallvynLocalVideoViewFactory());
        flutterEngine.getPlatformViewsController().getRegistry().registerViewFactory("com.sonoou.callvyndialer/remote_video_view", new CallvynVideoView.CallvynRemoteVideoViewFactory());
        flutterEngine.getPlatformViewsController().getRegistry().registerViewFactory("com.sonoou.callvyndialer/local_video_view", new CallvynVideoView.CallvynLocalVideoViewFactory());

        MethodChannel channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        methodChannel = channel;
        registerTelephonyListener();
        deliverPendingDialNumberIfAny();

        Call activeCallNow = CallvynInCallService.activeCall;
        if (activeCallNow != null && activeCallNow.getState() == Call.STATE_RINGING) {
            String incomingNum = (activeCallNow.getDetails() != null && activeCallNow.getDetails().getHandle() != null)
                    ? activeCallNow.getDetails().getHandle().getSchemeSpecificPart()
                    : (getIntent() != null ? getIntent().getStringExtra("incoming_number") : "");
            boolean isVideo = CallvynInCallService.isCallVideo(activeCallNow) || (getIntent() != null && getIntent().getBooleanExtra("is_video_call", false));
            String callerName = activeCallNow.getDetails() != null ? activeCallNow.getDetails().getCallerDisplayName() : "";
            if (callerName == null || callerName.isEmpty()) {
                if (getIntent() != null) {
                    callerName = getIntent().getStringExtra("caller_name");
                }
            }
            if (callerName == null || callerName.isEmpty()) {
                callerName = lookupContactName(incomingNum);
            }
            Map<String, Object> map = new HashMap<>();
            map.put("state", "RINGING");
            map.put("number", incomingNum != null ? incomingNum : "");
            map.put("name", callerName != null ? callerName : "");
            map.put("isVideo", isVideo);
            map.put("remoteTextureId", remoteTextureId);
            map.put("localTextureId", localTextureId);
            methodChannel.invokeMethod("onCallStateChanged", map);
        }

        channel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "getInitialCallState": {
                    Call activeCall = CallvynInCallService.activeCall;
                    if (activeCall != null) {
                        boolean isVideo = CallvynInCallService.isCallVideo(activeCall) || (getIntent() != null && getIntent().getBooleanExtra("is_video_call", false));
                        String stateName;
                        switch (activeCall.getState()) {
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
                        String number = (activeCall.getDetails() != null && activeCall.getDetails().getHandle() != null)
                                ? activeCall.getDetails().getHandle().getSchemeSpecificPart()
                                : (getIntent() != null ? getIntent().getStringExtra("incoming_number") : "");
                        String name = activeCall.getDetails() != null ? activeCall.getDetails().getCallerDisplayName() : "";
                        if (name == null || name.isEmpty()) {
                            if (getIntent() != null) name = getIntent().getStringExtra("caller_name");
                        }
                        if (name == null || name.isEmpty()) {
                            name = lookupContactName(number);
                        }
                        int simSlot = 1;
                        try {
                            PhoneAccountHandle handle = activeCall.getDetails() != null ? activeCall.getDetails().getAccountHandle() : null;
                            String id = handle != null ? handle.getId() : "";
                            if (id != null && (id.contains("1") || id.contains("sub_2") || id.contains("slot_1"))) {
                                simSlot = 2;
                            }
                        } catch (Exception ignored) {}

                        Map<String, Object> map = new HashMap<>();
                        map.put("state", stateName);
                        map.put("number", number != null ? number : "");
                        map.put("name", name != null ? name : "");
                        map.put("simSlot", simSlot);
                        map.put("isVideo", isVideo);
                        map.put("remoteTextureId", remoteTextureId);
                        map.put("localTextureId", localTextureId);
                        result.success(map);
                    } else if (getIntent() != null && getIntent().getBooleanExtra("is_incoming", false)) {
                        String number = getIntent().getStringExtra("incoming_number") != null ? getIntent().getStringExtra("incoming_number") : "";
                        String name = getIntent().getStringExtra("caller_name") != null ? getIntent().getStringExtra("caller_name") : "";
                        if (name.isEmpty()) {
                            name = lookupContactName(number);
                        }
                        boolean isVideo = getIntent().getBooleanExtra("is_video_call", false);
                        Map<String, Object> map = new HashMap<>();
                        map.put("state", "RINGING");
                        map.put("number", number);
                        map.put("name", name);
                        map.put("simSlot", 1);
                        map.put("isVideo", isVideo);
                        map.put("remoteTextureId", remoteTextureId);
                        map.put("localTextureId", localTextureId);
                        result.success(map);
                    } else {
                        result.success(null);
                    }
                    break;
                }

                case "getActiveSimSlots": {
                    List<Integer> activeSlots = new ArrayList<>();
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                            SubscriptionManager subscriptionManager = (SubscriptionManager) getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE);
                            if (subscriptionManager != null) {
                                try {
                                    List<SubscriptionInfo> activeSubscriptionInfoList = subscriptionManager.getActiveSubscriptionInfoList();
                                    if (activeSubscriptionInfoList != null && !activeSubscriptionInfoList.isEmpty()) {
                                        for (SubscriptionInfo info : activeSubscriptionInfoList) {
                                            int slotIndex = info.getSimSlotIndex();
                                            if (slotIndex >= 0) {
                                                int simNumber = slotIndex + 1;
                                                if (simNumber >= 1 && simNumber <= 2 && !activeSlots.contains(simNumber)) {
                                                    activeSlots.add(simNumber);
                                                }
                                            }
                                        }
                                    }
                                } catch (Exception se) {
                                    se.printStackTrace();
                                }
                            }
                        }

                        if (activeSlots.isEmpty()) {
                            TelephonyManager telephonyManager = (TelephonyManager) getSystemService(Context.TELEPHONY_SERVICE);
                            if (telephonyManager != null) {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    for (int i = 0; i <= 1; i++) {
                                        try {
                                            int state = telephonyManager.getSimState(i);
                                            if (state == TelephonyManager.SIM_STATE_READY) {
                                                int simNumber = i + 1;
                                                if (!activeSlots.contains(simNumber)) {
                                                    activeSlots.add(simNumber);
                                                }
                                            }
                                        } catch (Exception e) {
                                            e.printStackTrace();
                                        }
                                    }
                                }
                                if (activeSlots.isEmpty() && telephonyManager.getSimState() == TelephonyManager.SIM_STATE_READY) {
                                    activeSlots.add(2);
                                }
                            }
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                    result.success(activeSlots);
                    break;
                }

                case "getSimDetails": {
                    List<Map<String, Object>> simDetails = new ArrayList<>();
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                            SubscriptionManager subscriptionManager = (SubscriptionManager) getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE);
                            if (subscriptionManager != null) {
                                List<SubscriptionInfo> list = subscriptionManager.getActiveSubscriptionInfoList();
                                if (list != null && !list.isEmpty()) {
                                    for (SubscriptionInfo info : list) {
                                        int slotIndex = info.getSimSlotIndex();
                                        if (slotIndex >= 0) {
                                            int simNumber = slotIndex + 1;
                                            String carrierName = info.getDisplayName() != null ? info.getDisplayName().toString()
                                                    : (info.getCarrierName() != null ? info.getCarrierName().toString() : "SIM " + simNumber);
                                            Map<String, Object> map = new HashMap<>();
                                            map.put("slot", simNumber);
                                            map.put("name", carrierName);
                                            simDetails.add(map);
                                        }
                                    }
                                }
                            }
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                    result.success(simDetails);
                    break;
                }

                case "sendSms": {
                    String number = call.argument("number");
                    if (number != null && !number.isEmpty()) {
                        try {
                            String defaultSmsPackage = Telephony.Sms.getDefaultSmsPackage(this);
                            Intent intent = new Intent(Intent.ACTION_SENDTO);
                            intent.setData(Uri.parse("smsto:" + number));
                            if (defaultSmsPackage != null && !defaultSmsPackage.isEmpty()) {
                                intent.setPackage(defaultSmsPackage);
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            startActivity(intent);
                            result.success(true);
                        } catch (Exception e) {
                            try {
                                Intent intent = new Intent(Intent.ACTION_SENDTO);
                                intent.setData(Uri.parse("smsto:" + number));
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                startActivity(intent);
                                result.success(true);
                            } catch (Exception e2) {
                                result.success(false);
                            }
                        }
                    } else {
                        result.error("INVALID_NUMBER", "Number is empty", null);
                    }
                    break;
                }

                case "makeDirectCall": {
                    String number = call.argument("number");
                    if (number != null && !number.isEmpty()) {
                        try {
                            TelecomManager telecomManager = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
                            if (telecomManager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                Uri uri = Uri.fromParts("tel", number, null);
                                Bundle extras = new Bundle();
                                telecomManager.placeCall(uri, extras);
                                result.success(true);
                                return;
                            }

                            String encodedNumber = Uri.encode(number);
                            Uri callUri = Uri.parse("tel:" + encodedNumber);
                            Intent intent = new Intent(Intent.ACTION_CALL, callUri);
                            intent.setPackage("com.android.phone");
                            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            startActivity(intent);
                            result.success(true);
                        } catch (Exception e) {
                            try {
                                String encodedNumber = Uri.encode(number);
                                Uri callUri = Uri.parse("tel:" + encodedNumber);
                                Intent intent = new Intent(Intent.ACTION_CALL, callUri);
                                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                startActivity(intent);
                                result.success(true);
                            } catch (Exception e2) {
                                result.error("CALL_FAILED", e2.getMessage(), null);
                            }
                        }
                    } else {
                        result.error("INVALID_NUMBER", "Number is empty", null);
                    }
                    break;
                }

                case "makeVideoCall": {
                    String number = call.argument("number");
                    if (number != null && !number.isEmpty()) {
                        try {
                            TelecomManager telecomManager = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
                            Uri uri = Uri.fromParts("tel", number, null);
                            if (telecomManager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                Bundle extras = new Bundle();
                                extras.putInt(TelecomManager.EXTRA_START_CALL_WITH_VIDEO_STATE, VideoProfile.STATE_BIDIRECTIONAL);
                                extras.putInt("android.telecom.extra.START_CALL_WITH_VIDEO_STATE", VideoProfile.STATE_BIDIRECTIONAL);
                                extras.putBoolean("android.telecom.extra.START_CALL_WITH_SPEAKERPHONE_ON", true);
                                extras.putBoolean("videocall", true);
                                extras.putBoolean("com.android.phone.extra.video", true);
                                extras.putBoolean("org.codeaurora.extra.VT_CALL", true);
                                telecomManager.placeCall(uri, extras);
                                result.success(true);
                                return;
                            }

                            String encodedNumber = Uri.encode(number);
                            Uri callUri = Uri.parse("tel:" + encodedNumber);
                            Intent intent = new Intent(Intent.ACTION_CALL, callUri);
                            intent.putExtra(TelecomManager.EXTRA_START_CALL_WITH_VIDEO_STATE, VideoProfile.STATE_BIDIRECTIONAL);
                            intent.putExtra("android.telecom.extra.START_CALL_WITH_VIDEO_STATE", 3);
                            intent.putExtra("com.android.phone.extra.video", true);
                            intent.putExtra("videocall", true);
                            intent.putExtra("org.codeaurora.extra.VT_CALL", true);
                            intent.putExtra("android.intent.extra.VIDEO_CALL", true);
                            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            startActivity(intent);
                            result.success(true);
                        } catch (Exception e) {
                            try {
                                String encodedNumber = Uri.encode(number);
                                Uri callUri = Uri.parse("tel:" + encodedNumber);
                                Intent intent = new Intent(Intent.ACTION_CALL, callUri);
                                intent.putExtra(TelecomManager.EXTRA_START_CALL_WITH_VIDEO_STATE, 3);
                                intent.putExtra("com.android.phone.extra.video", true);
                                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                startActivity(intent);
                                result.success(true);
                            } catch (Exception e2) {
                                result.error("VIDEO_CALL_FAILED", e2.getMessage(), null);
                            }
                        }
                    } else {
                        result.error("INVALID_NUMBER", "Number is empty", null);
                    }
                    break;
                }

                case "createShortcut": {
                    String name = call.argument("name") != null ? call.argument("name") : "Contact";
                    String number = call.argument("number") != null ? call.argument("number") : "";
                    boolean isDirectDial = Boolean.TRUE.equals(call.argument("isDirectDial"));
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            ShortcutManager shortcutManager = getSystemService(ShortcutManager.class);
                            if (shortcutManager != null && shortcutManager.isRequestPinShortcutSupported()) {
                                Intent intent;
                                if (isDirectDial) {
                                    intent = new Intent(Intent.ACTION_CALL, Uri.parse("tel:" + number));
                                    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                } else {
                                    intent = new Intent(this, MainActivity.class);
                                    intent.setAction(Intent.ACTION_VIEW);
                                    intent.putExtra("contact_number", number);
                                    intent.putExtra("contact_name", name);
                                    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                }
                                ShortcutInfo pinShortcutInfo = new ShortcutInfo.Builder(this, "shortcut_" + System.currentTimeMillis())
                                    .setIcon(Icon.createWithResource(this, getApplicationInfo().icon))
                                    .setShortLabel(name)
                                    .setIntent(intent)
                                    .build();
                                shortcutManager.requestPinShortcut(pinShortcutInfo, null);
                                result.success(true);
                                return;
                            }
                        }
                        result.success(false);
                    } catch (Exception e) {
                        e.printStackTrace();
                        result.success(false);
                    }
                    break;
                }

                case "shareText": {
                    String text = call.argument("text") != null ? call.argument("text") : "";
                    try {
                        Intent shareIntent = new Intent(Intent.ACTION_SEND);
                        shareIntent.setType("text/plain");
                        shareIntent.putExtra(Intent.EXTRA_TEXT, text);
                        shareIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        Intent chooser = Intent.createChooser(shareIntent, "Share contact");
                        chooser.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        startActivity(chooser);
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "shareVCard": {
                    String name = call.argument("name") != null ? call.argument("name") : "Contact";
                    String number = call.argument("number") != null ? call.argument("number") : "";
                    String vcard = "BEGIN:VCARD\nVERSION:3.0\nFN:" + name + "\nTEL;TYPE=CELL:" + number + "\nEND:VCARD";
                    try {
                        File vcfFile = new File(getCacheDir(), name.replace(' ', '_') + ".vcf");
                        try (FileWriter writer = new FileWriter(vcfFile)) {
                            writer.write(vcard);
                        }
                        Uri uri = FileProvider.getUriForFile(
                            this,
                            getApplicationContext().getPackageName() + ".fileprovider",
                            vcfFile
                        );
                        Intent intent = new Intent(Intent.ACTION_SEND);
                        intent.setType("text/x-vcard");
                        intent.putExtra(Intent.EXTRA_STREAM, uri);
                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
                        Intent chooser = Intent.createChooser(intent, "Share contact file");
                        chooser.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        startActivity(chooser);
                        result.success(true);
                    } catch (Exception e) {
                        try {
                            Intent shareIntent = new Intent(Intent.ACTION_SEND);
                            shareIntent.setType("text/plain");
                            shareIntent.putExtra(Intent.EXTRA_TEXT, name + "\n" + number);
                            shareIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            Intent chooser = Intent.createChooser(shareIntent, "Share contact");
                            chooser.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            startActivity(chooser);
                            result.success(true);
                        } catch (Exception e2) {
                            result.success(false);
                        }
                    }
                    break;
                }

                case "isDefaultDialer": {
                    try {
                        boolean isDefault = false;
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            RoleManager roleManager = getSystemService(RoleManager.class);
                            if (roleManager != null && roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) {
                                isDefault = true;
                            }
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            TelecomManager telecomManager = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
                            if (telecomManager != null && getPackageName().equals(telecomManager.getDefaultDialerPackage())) {
                                isDefault = true;
                            }
                        }
                        result.success(isDefault);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "requestDefaultDialer": {
                    try {
                        boolean promptLaunched = false;
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            RoleManager roleManager = getSystemService(RoleManager.class);
                            if (roleManager != null && !roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) {
                                Intent intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER);
                                startActivityForResult(intent, 1001);
                                promptLaunched = true;
                            }
                        }
                        if (!promptLaunched && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            TelecomManager telecomManager = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
                            if (telecomManager != null && !getPackageName().equals(telecomManager.getDefaultDialerPackage())) {
                                Intent intent = new Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER);
                                intent.putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, getPackageName());
                                startActivityForResult(intent, 1001);
                                promptLaunched = true;
                            }
                        }
                        result.success(promptLaunched);
                    } catch (Exception e) {
                        try {
                            Intent intent = new Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS);
                            startActivity(intent);
                            result.success(true);
                        } catch (Exception e2) {
                            result.success(false);
                        }
                    }
                    break;
                }

                case "answerNativeCall": {
                    try {
                        final boolean asVideo = Boolean.TRUE.equals(call.argument("isVideo"));
                        new Handler(Looper.getMainLooper()).post(() -> CallvynInCallService.answerCall(asVideo));
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "upgradeToVideoCall": {
                    try {
                        new Handler(Looper.getMainLooper()).post(CallvynInCallService::upgradeToVideoCall);
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "acceptVideoUpgrade": {
                    try {
                        new Handler(Looper.getMainLooper()).post(CallvynInCallService::acceptVideoUpgrade);
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "declineVideoUpgrade": {
                    try {
                        new Handler(Looper.getMainLooper()).post(CallvynInCallService::declineVideoUpgrade);
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "getVideoTextures": {
                    Map<String, Object> map = new HashMap<>();
                    map.put("remoteTextureId", remoteTextureId);
                    map.put("localTextureId", localTextureId);
                    result.success(map);
                    break;
                }

                case "switchCamera": {
                    try {
                        final boolean useBack = Boolean.TRUE.equals(call.argument("useBack"));
                        new Handler(Looper.getMainLooper()).post(() -> CallvynInCallService.switchCamera(useBack));
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "moveAppToBack": {
                    try {
                        wasLaunchedByIncoming = false;
                        moveTaskToBack(true);
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "endNativeCall": {
                    try {
                        final boolean wasIncoming = wasLaunchedByIncoming;
                        new Handler(Looper.getMainLooper()).post(() -> {
                            Call activeCall = CallvynInCallService.activeCall;
                            if (activeCall != null) {
                                if (activeCall.getState() == Call.STATE_RINGING) {
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                        activeCall.reject(false, null);
                                    } else {
                                        activeCall.disconnect();
                                    }
                                } else {
                                    activeCall.disconnect();
                                }
                            }
                            if (wasIncoming) {
                                wasLaunchedByIncoming = false;
                                moveTaskToBack(true);
                            }
                        });
                        TelecomManager telecomManager = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
                        if (telecomManager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            telecomManager.endCall();
                        }
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "deleteCallLog": {
                    String number = call.argument("number");
                    String id = call.argument("id");
                    try {
                        if (number != null && !number.isEmpty()) {
                            getContentResolver().delete(
                                CallLog.Calls.CONTENT_URI,
                                CallLog.Calls.NUMBER + " = ?",
                                new String[]{number}
                            );
                        } else if (id != null && !id.isEmpty()) {
                            getContentResolver().delete(
                                CallLog.Calls.CONTENT_URI,
                                CallLog.Calls._ID + " = ?",
                                new String[]{id}
                            );
                        }
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "copyToClipboard": {
                    String text = call.argument("text") != null ? call.argument("text") : "";
                    try {
                        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                        if (clipboard != null) {
                            ClipData clip = ClipData.newPlainText("text", text);
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                PersistableBundle extras = new PersistableBundle();
                                extras.putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true);
                                clip.getDescription().setExtras(extras);
                            }
                            clipboard.setPrimaryClip(clip);
                        }
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "getWallpaper": {
                    try {
                        WallpaperManager wallpaperManager = WallpaperManager.getInstance(this);
                        Drawable drawable = wallpaperManager.getDrawable();
                        if (drawable != null) {
                            Bitmap bitmap;
                            if (drawable instanceof BitmapDrawable) {
                                bitmap = ((BitmapDrawable) drawable).getBitmap();
                            } else {
                                Bitmap bmp = Bitmap.createBitmap(
                                    Math.max(drawable.getIntrinsicWidth(), 100),
                                    Math.max(drawable.getIntrinsicHeight(), 100),
                                    Bitmap.Config.ARGB_8888
                                );
                                Canvas canvas = new Canvas(bmp);
                                drawable.setBounds(0, 0, canvas.getWidth(), canvas.getHeight());
                                drawable.draw(canvas);
                                bitmap = bmp;
                            }
                            int maxDim = 1080;
                            float scale = (float) maxDim / Math.max(Math.max(bitmap.getWidth(), bitmap.getHeight()), 1);
                            Bitmap scaledBitmap = scale < 1.0f
                                    ? Bitmap.createScaledBitmap(bitmap, (int) (bitmap.getWidth() * scale), (int) (bitmap.getHeight() * scale), true)
                                    : bitmap;
                            ByteArrayOutputStream stream = new ByteArrayOutputStream();
                            scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream);
                            result.success(stream.toByteArray());
                        } else {
                            result.success(null);
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                        result.success(null);
                    }
                    break;
                }

                case "setSpeaker": {
                    final boolean enabled = Boolean.TRUE.equals(call.argument("enabled"));
                    try {
                        if (CallvynInCallService.instance != null) {
                            new Handler(Looper.getMainLooper()).post(() -> {
                                if (CallvynInCallService.instance != null) {
                                    CallvynInCallService.instance.setCallSpeaker(enabled);
                                }
                            });
                        } else {
                            AudioManager audioManager = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
                            if (audioManager != null) {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    if (enabled) {
                                        AudioDeviceInfo speakerDevice = null;
                                        for (AudioDeviceInfo dev : audioManager.getAvailableCommunicationDevices()) {
                                            if (dev.getType() == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                                                speakerDevice = dev;
                                                break;
                                            }
                                        }
                                        if (speakerDevice != null) {
                                            audioManager.setCommunicationDevice(speakerDevice);
                                        } else {
                                            audioManager.setSpeakerphoneOn(true);
                                        }
                                    } else {
                                        audioManager.clearCommunicationDevice();
                                        audioManager.setSpeakerphoneOn(false);
                                    }
                                } else {
                                    audioManager.setSpeakerphoneOn(enabled);
                                }
                            }
                        }
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "setMute": {
                    final boolean enabled = Boolean.TRUE.equals(call.argument("enabled"));
                    try {
                        if (CallvynInCallService.instance != null) {
                            new Handler(Looper.getMainLooper()).post(() -> {
                                if (CallvynInCallService.instance != null) {
                                    CallvynInCallService.instance.setCallMuted(enabled);
                                }
                            });
                        } else {
                            AudioManager audioManager = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
                            if (audioManager != null) {
                                audioManager.setMicrophoneMute(enabled);
                            }
                        }
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "setHold": {
                    final boolean enabled = Boolean.TRUE.equals(call.argument("enabled"));
                    try {
                        new Handler(Looper.getMainLooper()).post(() -> {
                            Call activeCall = CallvynInCallService.activeCall;
                            if (activeCall != null) {
                                if (enabled) {
                                    activeCall.hold();
                                } else {
                                    activeCall.unhold();
                                }
                            }
                        });
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "sendDtmf": {
                    String digit = call.argument("digit") != null ? call.argument("digit") : "";
                    if (!digit.isEmpty()) {
                        final char charDigit = digit.charAt(0);
                        try {
                            new Handler(Looper.getMainLooper()).post(() -> CallvynInCallService.sendDtmf(charDigit));
                            result.success(true);
                        } catch (Exception e) {
                            result.success(false);
                        }
                    } else {
                        result.success(false);
                    }
                    break;
                }

                case "isIgnoringBatteryOptimizations": {
                    try {
                        PowerManager powerManager = (PowerManager) getSystemService(Context.POWER_SERVICE);
                        boolean isIgnoring = (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) ||
                                (powerManager != null && powerManager.isIgnoringBatteryOptimizations(getPackageName()));
                        result.success(isIgnoring);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "requestIgnoreBatteryOptimizations": {
                    try {
                        PowerManager powerManager = (PowerManager) getSystemService(Context.POWER_SERVICE);
                        if (powerManager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            if (!powerManager.isIgnoringBatteryOptimizations(getPackageName())) {
                                try {
                                    Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                                    intent.setData(Uri.parse("package:" + getPackageName()));
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                    startActivity(intent);
                                    result.success(true);
                                } catch (Exception e) {
                                    Intent settingsIntent = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
                                    settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                    startActivity(settingsIntent);
                                    result.success(true);
                                }
                            } else {
                                result.success(true);
                            }
                        } else {
                            result.success(true);
                        }
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "startForegroundService": {
                    try {
                        CallvynForegroundService.start(this);
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                case "saveNoteFile": {
                    String fileName = call.argument("fileName") != null ? call.argument("fileName") : "note.txt";
                    String content = call.argument("content") != null ? call.argument("content") : "";
                    try {
                        File baseDir = android.os.Environment.getExternalStorageDirectory();
                        File notesDir = new File(baseDir, "Callvyn-Dialer/call-notes");
                        if (!notesDir.exists()) {
                            notesDir.mkdirs();
                        }
                        File file = new File(notesDir, fileName);
                        if (!notesDir.canWrite()) {
                            File appDir = getExternalFilesDir(null);
                            File fallbackDir = new File(appDir, "Callvyn-Dialer/call-notes");
                            if (!fallbackDir.exists()) fallbackDir.mkdirs();
                            file = new File(fallbackDir, fileName);
                        }
                        try (FileWriter writer = new FileWriter(file)) {
                            writer.write(content);
                        }
                        result.success(file.getAbsolutePath());
                    } catch (Exception e) {
                        try {
                            File appDir = getExternalFilesDir(null);
                            File notesDir = new File(appDir, "Callvyn-Dialer/call-notes");
                            if (!notesDir.exists()) notesDir.mkdirs();
                            File file = new File(notesDir, fileName);
                            try (FileWriter writer = new FileWriter(file)) {
                                writer.write(content);
                            }
                            result.success(file.getAbsolutePath());
                        } catch (Exception e2) {
                            result.error("SAVE_FAILED", e2.getMessage(), null);
                        }
                    }
                    break;
                }

                case "openWithOtherApp": {
                    String filePath = call.argument("filePath");
                    if (filePath != null && !filePath.isEmpty()) {
                        try {
                            File file = new File(filePath);
                            Uri uri = FileProvider.getUriForFile(
                                this,
                                getPackageName() + ".fileprovider",
                                file
                            );
                            Intent intent = new Intent(Intent.ACTION_VIEW);
                            intent.setDataAndType(uri, "text/plain");
                            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            Intent chooser = Intent.createChooser(intent, "Open Note with");
                            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            startActivity(chooser);
                            result.success(true);
                        } catch (Exception e) {
                            try {
                                File file = new File(filePath);
                                Uri uri = FileProvider.getUriForFile(
                                    this,
                                    getPackageName() + ".fileprovider",
                                    file
                                );
                                Intent shareIntent = new Intent(Intent.ACTION_SEND);
                                shareIntent.setType("text/plain");
                                shareIntent.putExtra(Intent.EXTRA_STREAM, uri);
                                shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                shareIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                Intent chooser = Intent.createChooser(shareIntent, "Share Note");
                                chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                startActivity(chooser);
                                result.success(true);
                            } catch (Exception e2) {
                                result.error("OPEN_FAILED", e2.getMessage(), null);
                            }
                        }
                    } else {
                        result.error("INVALID_PATH", "File path is empty", null);
                    }
                    break;
                }

                case "isRootAvailable": {
                    result.success(RootHelper.isRootAvailable());
                    break;
                }

                case "requestRootPermission": {
                    result.success(RootHelper.requestRoot());
                    break;
                }

                case "startCallRecording": {
                    String fileName = call.argument("fileName") != null ? call.argument("fileName") : "call_recording.mp3";
                    try {
                        File baseDir = android.os.Environment.getExternalStorageDirectory();
                        File recordingsDir = new File(baseDir, "Callvyn-Dialer/recorded-calls");
                        if (!recordingsDir.exists()) {
                            recordingsDir.mkdirs();
                        }
                        File file = new File(recordingsDir, fileName);
                        if (!recordingsDir.canWrite()) {
                            File appDir = getExternalFilesDir(null);
                            File fallbackDir = new File(appDir, "Callvyn-Dialer/recorded-calls");
                            if (!fallbackDir.exists()) fallbackDir.mkdirs();
                            file = new File(fallbackDir, fileName);
                        }

                        if (callAudioRecorder == null) {
                            callAudioRecorder = new CallAudioRecorder(this);
                        }
                        boolean started = callAudioRecorder.start(file);
                        if (started) {
                            currentRecordingPath = file.getAbsolutePath();
                            result.success(file.getAbsolutePath());
                        } else {
                            result.error("RECORDING_FAILED", "Failed to start AudioRecord stream", null);
                        }
                    } catch (Exception e) {
                        result.error("RECORDING_FAILED", e.getMessage(), null);
                    }
                    break;
                }

                case "stopCallRecording": {
                    try {
                        String path = callAudioRecorder != null ? callAudioRecorder.stop() : currentRecordingPath;
                        callAudioRecorder = null;
                        currentRecordingPath = null;
                        result.success(path);
                    } catch (Exception e) {
                        callAudioRecorder = null;
                        result.success(currentRecordingPath);
                    }
                    break;
                }

                case "getCallLogs": {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        if (checkSelfPermission(Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(new String[]{Manifest.permission.READ_CALL_LOG, Manifest.permission.READ_PHONE_STATE}, 101);
                        }
                    }
                    List<Map<String, Object>> logs = getNativeCallLogs();
                    result.success(logs);
                    break;
                }

                case "getSystemRingtones": {
                    List<Map<String, Object>> ringtones = getSystemRingtonesList();
                    result.success(ringtones);
                    break;
                }

                case "getDeviceAudioFiles": {
                    List<Map<String, Object>> audioFiles = getDeviceAudioFilesList();
                    result.success(audioFiles);
                    break;
                }

                case "playRingtonePreview": {
                    String uriOrPath = call.argument("uri") != null ? call.argument("uri")
                            : (call.argument("path") != null ? call.argument("path") : "");
                    playRingtonePreview(uriOrPath);
                    result.success(true);
                    break;
                }

                case "writeLog": {
                    try {
                        String level = call.argument("level") != null ? call.argument("level") : "INFO";
                        String tag = call.argument("tag") != null ? call.argument("tag") : "Flutter";
                        String msg = call.argument("message") != null ? call.argument("message") : "";
                        String stack = call.argument("stackTrace");
                        switch (level) {
                            case "ERROR":
                                CallvynLogger.logError(tag, msg, stack);
                                break;
                            case "WARN":
                                CallvynLogger.w(tag, msg);
                                break;
                            case "DEBUG":
                                CallvynLogger.d(tag, msg);
                                break;
                            default:
                                CallvynLogger.i(tag, msg);
                                break;
                        }
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }

                default:
                    result.notImplemented();
                    break;
            }
        });
    }

    private List<Map<String, Object>> getSystemRingtonesList() {
        List<Map<String, Object>> list = new ArrayList<>();
        try {
            RingtoneManager ringtoneManager = new RingtoneManager(this);
            ringtoneManager.setType(RingtoneManager.TYPE_RINGTONE);
            Cursor cursor = ringtoneManager.getCursor();
            while (cursor != null && cursor.moveToNext()) {
                String title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX);
                Uri uri = ringtoneManager.getRingtoneUri(cursor.getPosition());
                String id = cursor.getString(RingtoneManager.ID_COLUMN_INDEX);
                Map<String, Object> map = new HashMap<>();
                map.put("title", title != null ? title : "Ringtone");
                map.put("uri", uri != null ? uri.toString() : "");
                map.put("id", id != null ? id : "");
                map.put("duration", "00:30");
                list.add(map);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return list;
    }

    private List<Map<String, Object>> getDeviceAudioFilesList() {
        List<Map<String, Object>> list = new ArrayList<>();
        try {
            Uri uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI;
            String[] projection = new String[]{
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.DISPLAY_NAME,
                MediaStore.Audio.Media.DATA,
                MediaStore.Audio.Media.SIZE,
                MediaStore.Audio.Media.DATE_MODIFIED,
                MediaStore.Audio.Media.DURATION
            };
            String selection = MediaStore.Audio.Media.IS_MUSIC + " != 0 OR " +
                    MediaStore.Audio.Media.IS_RINGTONE + " != 0 OR " +
                    MediaStore.Audio.Media.DISPLAY_NAME + " LIKE '%.mp3' OR " +
                    MediaStore.Audio.Media.DISPLAY_NAME + " LIKE '%.m4a' OR " +
                    MediaStore.Audio.Media.DISPLAY_NAME + " LIKE '%.aac' OR " +
                    MediaStore.Audio.Media.DISPLAY_NAME + " LIKE '%.wav' OR " +
                    MediaStore.Audio.Media.DISPLAY_NAME + " LIKE '%.ogg' OR " +
                    MediaStore.Audio.Media.DISPLAY_NAME + " LIKE '%.opus'";
            String sortOrder = MediaStore.Audio.Media.DATE_MODIFIED + " DESC";

            try (Cursor c = getContentResolver().query(uri, projection, selection, null, sortOrder)) {
                if (c != null) {
                    int nameIdx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME);
                    int pathIdx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA);
                    int sizeIdx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE);
                    int dateIdx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED);
                    int durIdx = c.getColumnIndex(MediaStore.Audio.Media.DURATION);

                    while (c.moveToNext()) {
                        String name = c.getString(nameIdx);
                        String path = c.getString(pathIdx);
                        long size = c.getLong(sizeIdx);
                        long dateModified = c.getLong(dateIdx);
                        long durationMs = durIdx != -1 ? c.getLong(durIdx) : 0L;

                        if (path != null && !path.isEmpty() && size > 0) {
                            Map<String, Object> map = new HashMap<>();
                            map.put("name", name != null ? name : "Audio");
                            map.put("path", path);
                            map.put("size", size);
                            map.put("dateModified", dateModified);
                            map.put("durationMs", durationMs);
                            list.add(map);
                        }
                    }
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return list;
    }

    private void playRingtonePreview(String uriOrPath) {
        stopRingtonePreview();
        try {
            previewMediaPlayer = new MediaPlayer();
            if (uriOrPath.startsWith("content://") || uriOrPath.startsWith("android.resource://")) {
                previewMediaPlayer.setDataSource(this, Uri.parse(uriOrPath));
            } else {
                previewMediaPlayer.setDataSource(uriOrPath);
            }
            previewMediaPlayer.setAudioStreamType(AudioManager.STREAM_RING);
            previewMediaPlayer.prepare();
            previewMediaPlayer.start();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void stopRingtonePreview() {
        try {
            if (previewMediaPlayer != null) {
                previewMediaPlayer.stop();
                previewMediaPlayer.release();
            }
        } catch (Exception ignored) {}
        previewMediaPlayer = null;
    }

    private List<Map<String, Object>> getNativeCallLogs() {
        List<Map<String, Object>> callLogsList = new ArrayList<>();
        try {
            Uri uri = CallLog.Calls.CONTENT_URI;
            String[] projection = new String[]{
                CallLog.Calls._ID,
                CallLog.Calls.NUMBER,
                CallLog.Calls.CACHED_NAME,
                CallLog.Calls.DATE,
                CallLog.Calls.DURATION,
                CallLog.Calls.TYPE,
                CallLog.Calls.PHONE_ACCOUNT_ID
            };

            try (Cursor c = getContentResolver().query(uri, projection, null, null, CallLog.Calls.DATE + " DESC")) {
                if (c != null) {
                    int idIndex = c.getColumnIndex(CallLog.Calls._ID);
                    int numberIndex = c.getColumnIndex(CallLog.Calls.NUMBER);
                    int nameIndex = c.getColumnIndex(CallLog.Calls.CACHED_NAME);
                    int dateIndex = c.getColumnIndex(CallLog.Calls.DATE);
                    int durationIndex = c.getColumnIndex(CallLog.Calls.DURATION);
                    int typeIndex = c.getColumnIndex(CallLog.Calls.TYPE);
                    int accountIdIndex = c.getColumnIndex(CallLog.Calls.PHONE_ACCOUNT_ID);

                    while (c.moveToNext()) {
                        String id = idIndex >= 0 ? c.getString(idIndex) : "";
                        String number = (numberIndex >= 0 && c.getString(numberIndex) != null) ? c.getString(numberIndex) : "";
                        String name = (nameIndex >= 0 && c.getString(nameIndex) != null) ? c.getString(nameIndex) : "";
                        long date = dateIndex >= 0 ? c.getLong(dateIndex) : 0L;
                        int duration = durationIndex >= 0 ? c.getInt(durationIndex) : 0;
                        int type = typeIndex >= 0 ? c.getInt(typeIndex) : 1;
                        String accountId = (accountIdIndex >= 0 && c.getString(accountIdIndex) != null) ? c.getString(accountIdIndex) : "";

                        if (!number.isEmpty()) {
                            Map<String, Object> map = new HashMap<>();
                            map.put("id", id);
                            map.put("number", number);
                            map.put("name", name);
                            map.put("date", date);
                            map.put("duration", duration);
                            map.put("type", type);
                            map.put("accountId", accountId);
                            callLogsList.add(map);
                        }
                    }
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return callLogsList;
    }

    @androidx.annotation.RequiresApi(api = Build.VERSION_CODES.S)
    private static class CallStateCallback extends TelephonyCallback implements TelephonyCallback.CallStateListener {
        private final MainActivity activity;

        CallStateCallback(MainActivity activity) {
            this.activity = activity;
        }

        @Override
        public void onCallStateChanged(int state) {
            if (activity != null) {
                activity.handleTelephonyCallState(state);
            }
        }
    }

    private void registerTelephonyListener() {
        try {
            TelephonyManager telephonyManager = (TelephonyManager) getSystemService(Context.TELEPHONY_SERVICE);
            if (telephonyManager == null) return;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                telephonyManager.registerTelephonyCallback(
                    getMainExecutor(),
                    new CallStateCallback(this)
                );
            } else {
                @SuppressWarnings("deprecation")
                PhoneStateListener listener = new PhoneStateListener() {
                    @Deprecated
                    @Override
                    public void onCallStateChanged(int state, String phoneNumber) {
                        handleTelephonyCallState(state);
                    }
                };
                telephonyManager.listen(listener, PhoneStateListener.LISTEN_CALL_STATE);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handleTelephonyCallState(int state) {
        if (state == TelephonyManager.CALL_STATE_IDLE) {
            if (methodChannel != null) {
                Map<String, Object> map = new HashMap<>();
                map.put("state", "DISCONNECTED");
                methodChannel.invokeMethod("onCallStateChanged", map);
            }
        }
    }
}

class RootHelper {
    public static boolean isRootAvailable() {
        try {
            Process process = Runtime.getRuntime().exec(new String[]{"su", "-c", "id"});
            int exitCode = process.waitFor();
            return exitCode == 0;
        } catch (Exception ignored) {
            return false;
        }
    }

    public static boolean requestRoot() {
        return isRootAvailable();
    }

    public static void prepareRootRecording(String packageName) {
        try {
            String[] commands = new String[]{
                "setenforce 0",
                "pm grant " + packageName + " android.permission.CAPTURE_AUDIO_OUTPUT",
                "pm grant " + packageName + " android.permission.MODIFY_PHONE_STATE",
                "pm grant " + packageName + " android.permission.RECORD_AUDIO"
            };
            for (String cmd : commands) {
                try {
                    Runtime.getRuntime().exec(new String[]{"su", "-c", cmd}).waitFor();
                } catch (Exception ignored) {}
            }
        } catch (Exception ignored) {}
    }
}

class CallAudioRecorder {
    private final Context context;
    private MediaRecorder mediaRecorder;
    private AudioRecord audioRecord;
    private AacEncoder aacEncoder;
    private boolean isRecording = false;
    private Thread recordingThread;
    private File targetOutputFile;
    private AcousticEchoCanceler aec;
    private NoiseSuppressor ns;
    private AutomaticGainControl agc;

    public CallAudioRecorder(Context context) {
        this.context = context;
    }

    public boolean start(File outputFile) {
        stop();
        targetOutputFile = outputFile;

        try {
            AudioManager audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
            if (audioManager != null) {
                audioManager.setMicrophoneMute(false);
            }
        } catch (Exception ignored) {}

        if (RootHelper.isRootAvailable()) {
            RootHelper.prepareRootRecording(context.getPackageName());
            if (startSystemVoiceCallStream(outputFile)) {
                return true;
            }
        }

        if (startAudioRecordStream(outputFile)) {
            return true;
        }

        return startMediaRecorderFallback(outputFile);
    }

    private boolean startSystemVoiceCallStream(File outputFile) {
        int[] sampleRates = new int[]{16000, 8000, 44100, 48000};
        int channelConfig = AudioFormat.CHANNEL_IN_MONO;
        int audioFormat = AudioFormat.ENCODING_PCM_16BIT;

        int[] systemSources = new int[]{
            MediaRecorder.AudioSource.VOICE_CALL,
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            MediaRecorder.AudioSource.VOICE_UPLINK,
            MediaRecorder.AudioSource.VOICE_DOWNLINK
        };

        AudioRecord record = null;
        int chosenSampleRate = 16000;
        int chosenBufferSize = 8192;

        outerLoop:
        for (int sr : sampleRates) {
            int minBuf = AudioRecord.getMinBufferSize(sr, channelConfig, audioFormat);
            if (minBuf <= 0) continue;
            int bufSize = minBuf * 4;

            for (int src : systemSources) {
                try {
                    AudioRecord r = new AudioRecord(src, sr, channelConfig, audioFormat, bufSize);
                    if (r.getState() == AudioRecord.STATE_INITIALIZED) {
                        record = r;
                        chosenSampleRate = sr;
                        chosenBufferSize = bufSize;
                        break outerLoop;
                    } else {
                        r.release();
                    }
                } catch (Exception ignored) {}
            }
        }

        if (record == null) return false;
        audioRecord = record;

        if (AcousticEchoCanceler.isAvailable()) {
            try {
                aec = AcousticEchoCanceler.create(record.getAudioSessionId());
                if (aec != null) aec.setEnabled(true);
            } catch (Exception ignored) {}
        }
        if (NoiseSuppressor.isAvailable()) {
            try {
                ns = NoiseSuppressor.create(record.getAudioSessionId());
                if (ns != null) ns.setEnabled(true);
            } catch (Exception ignored) {}
        }
        if (AutomaticGainControl.isAvailable()) {
            try {
                agc = AutomaticGainControl.create(record.getAudioSessionId());
                if (agc != null) agc.setEnabled(true);
            } catch (Exception ignored) {}
        }

        AacEncoder encoder = new AacEncoder(chosenSampleRate, 1, 128000);
        if (!encoder.init()) {
            record.release();
            audioRecord = null;
            return false;
        }
        aacEncoder = encoder;

        isRecording = true;

        try {
            record.startRecording();
        } catch (Exception e) {
            e.printStackTrace();
            record.release();
            audioRecord = null;
            encoder.release();
            aacEncoder = null;
            return false;
        }

        final int bufferSize = chosenBufferSize;
        final AudioRecord finalRecord1 = record;
        recordingThread = new Thread(() -> {
            try (FileOutputStream fos = new FileOutputStream(outputFile)) {
                byte[] buffer = new byte[bufferSize];
                while (isRecording) {
                    int read = finalRecord1.read(buffer, 0, buffer.length);
                    if (read > 0) {
                        encoder.encode(buffer, read, fos);
                    }
                }
                encoder.flush(fos);
                fos.flush();
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
        recordingThread.start();
        return true;
    }

    private boolean startAudioRecordStream(File outputFile) {
        int[] sampleRates = new int[]{16000, 48000, 8000, 44100};
        int channelConfig = AudioFormat.CHANNEL_IN_MONO;
        int audioFormat = AudioFormat.ENCODING_PCM_16BIT;

        int[] audioRecordSources = new int[]{
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            MediaRecorder.AudioSource.MIC,
            MediaRecorder.AudioSource.DEFAULT
        };

        AudioRecord record = null;
        int chosenSampleRate = 16000;
        int chosenBufferSize = 8192;

        outerLoop:
        for (int sr : sampleRates) {
            int minBuf = AudioRecord.getMinBufferSize(sr, channelConfig, audioFormat);
            if (minBuf <= 0) continue;
            int bufSize = minBuf * 4;

            for (int src : audioRecordSources) {
                try {
                    AudioRecord r = new AudioRecord(src, sr, channelConfig, audioFormat, bufSize);
                    if (r.getState() == AudioRecord.STATE_INITIALIZED) {
                        record = r;
                        chosenSampleRate = sr;
                        chosenBufferSize = bufSize;
                        break outerLoop;
                    } else {
                        r.release();
                    }
                } catch (Exception ignored) {}
            }
        }

        if (record == null) return false;
        audioRecord = record;

        if (AcousticEchoCanceler.isAvailable()) {
            try {
                aec = AcousticEchoCanceler.create(record.getAudioSessionId());
                if (aec != null) aec.setEnabled(true);
            } catch (Exception ignored) {}
        }
        if (NoiseSuppressor.isAvailable()) {
            try {
                ns = NoiseSuppressor.create(record.getAudioSessionId());
                if (ns != null) ns.setEnabled(true);
            } catch (Exception ignored) {}
        }
        if (AutomaticGainControl.isAvailable()) {
            try {
                agc = AutomaticGainControl.create(record.getAudioSessionId());
                if (agc != null) agc.setEnabled(true);
            } catch (Exception ignored) {}
        }

        AacEncoder encoder = new AacEncoder(chosenSampleRate, 1, 128000);
        if (!encoder.init()) {
            record.release();
            audioRecord = null;
            return false;
        }
        aacEncoder = encoder;

        isRecording = true;

        try {
            record.startRecording();
        } catch (Exception e) {
            e.printStackTrace();
            record.release();
            audioRecord = null;
            encoder.release();
            aacEncoder = null;
            return false;
        }

        final int bufferSize2 = chosenBufferSize;
        final AudioRecord finalRecord2 = record;
        recordingThread = new Thread(() -> {
            try (FileOutputStream fos = new FileOutputStream(outputFile)) {
                byte[] buffer = new byte[bufferSize2];
                while (isRecording) {
                    int read = finalRecord2.read(buffer, 0, buffer.length);
                    if (read > 0) {
                        encoder.encode(buffer, read, fos);
                    }
                }
                encoder.flush(fos);
                fos.flush();
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
        recordingThread.start();
        return true;
    }

    private boolean startMediaRecorderFallback(File outputFile) {
        int[] mediaRecorderSources = new int[]{
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            MediaRecorder.AudioSource.MIC,
            MediaRecorder.AudioSource.DEFAULT
        };

        for (int src : mediaRecorderSources) {
            try {
                MediaRecorder mr;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    mr = new MediaRecorder(context);
                } else {
                    @SuppressWarnings("deprecation")
                    MediaRecorder legacyMr = new MediaRecorder();
                    mr = legacyMr;
                }
                mr.setAudioSource(src);
                try {
                    mr.setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS);
                } catch (Exception ignored) {
                    mr.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
                }
                mr.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
                mr.setAudioChannels(1);
                mr.setAudioSamplingRate(16000);
                mr.setAudioEncodingBitRate(64000);
                mr.setOutputFile(outputFile.getAbsolutePath());
                mr.prepare();
                mr.start();
                mediaRecorder = mr;
                isRecording = true;
                return true;
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        return false;
    }

    public String stop() {
        if (!isRecording) return targetOutputFile != null ? targetOutputFile.getAbsolutePath() : null;
        isRecording = false;

        try {
            if (audioRecord != null) {
                audioRecord.stop();
                audioRecord.release();
            }
        } catch (Exception ignored) {}
        audioRecord = null;

        try {
            if (aec != null) {
                aec.release();
                aec = null;
            }
            if (ns != null) {
                ns.release();
                ns = null;
            }
            if (agc != null) {
                agc.release();
                agc = null;
            }
        } catch (Exception ignored) {}

        try {
            if (mediaRecorder != null) {
                mediaRecorder.stop();
                mediaRecorder.release();
            }
        } catch (Exception ignored) {}
        mediaRecorder = null;

        try {
            if (recordingThread != null) {
                recordingThread.join(1200);
            }
        } catch (Exception ignored) {}
        recordingThread = null;

        if (aacEncoder != null) {
            aacEncoder.release();
            aacEncoder = null;
        }

        return targetOutputFile != null ? targetOutputFile.getAbsolutePath() : null;
    }
}

class AacEncoder {
    private final int sampleRate;
    private final int channelCount;
    private final int bitRate;
    private MediaCodec mediaCodec;
    private static final String MIME = "audio/mp4a-latm";
    private long presentationTimeUs = 0L;

    public AacEncoder(int sampleRate, int channelCount, int bitRate) {
        this.sampleRate = sampleRate;
        this.channelCount = channelCount;
        this.bitRate = bitRate;
    }

    public boolean init() {
        try {
            MediaFormat format = MediaFormat.createAudioFormat(MIME, sampleRate, channelCount);
            format.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC);
            format.setInteger(MediaFormat.KEY_BIT_RATE, bitRate);
            format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384);

            MediaCodec codec = MediaCodec.createEncoderByType(MIME);
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
            codec.start();
            mediaCodec = codec;
            presentationTimeUs = 0L;
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    public void encode(byte[] pcmData, int length, OutputStream fos) {
        MediaCodec codec = mediaCodec;
        if (codec == null || length <= 0) return;

        int inputIndex = codec.dequeueInputBuffer(5000);
        if (inputIndex >= 0) {
            ByteBuffer inputBuffer = codec.getInputBuffer(inputIndex);
            if (inputBuffer != null) {
                inputBuffer.clear();
                inputBuffer.put(pcmData, 0, length);
                long pts = presentationTimeUs;
                presentationTimeUs += (length * 1_000_000L / (2L * sampleRate));
                codec.queueInputBuffer(inputIndex, 0, length, pts, 0);
            }
        }

        MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();
        int outputIndex = codec.dequeueOutputBuffer(bufferInfo, 5000);
        while (outputIndex >= 0) {
            ByteBuffer outputBuffer = codec.getOutputBuffer(outputIndex);
            if (outputBuffer != null && bufferInfo.size > 0) {
                byte[] outData = new byte[bufferInfo.size];
                outputBuffer.position(bufferInfo.offset);
                outputBuffer.limit(bufferInfo.offset + bufferInfo.size);
                outputBuffer.get(outData);

                try {
                    byte[] adtsHeader = createAdtsHeader(outData.length, sampleRate, channelCount);
                    fos.write(adtsHeader);
                    fos.write(outData);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
            codec.releaseOutputBuffer(outputIndex, false);
            outputIndex = codec.dequeueOutputBuffer(bufferInfo, 0);
        }
    }

    public void flush(OutputStream fos) {
        MediaCodec codec = mediaCodec;
        if (codec == null) return;
        MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();
        int outputIndex = codec.dequeueOutputBuffer(bufferInfo, 10000);
        while (outputIndex >= 0) {
            ByteBuffer outputBuffer = codec.getOutputBuffer(outputIndex);
            if (outputBuffer != null && bufferInfo.size > 0) {
                byte[] outData = new byte[bufferInfo.size];
                outputBuffer.position(bufferInfo.offset);
                outputBuffer.limit(bufferInfo.offset + bufferInfo.size);
                outputBuffer.get(outData);

                try {
                    byte[] adtsHeader = createAdtsHeader(outData.length, sampleRate, channelCount);
                    fos.write(adtsHeader);
                    fos.write(outData);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
            codec.releaseOutputBuffer(outputIndex, false);
            outputIndex = codec.dequeueOutputBuffer(bufferInfo, 0);
        }
    }

    public void release() {
        try {
            if (mediaCodec != null) {
                mediaCodec.stop();
                mediaCodec.release();
            }
        } catch (Exception ignored) {}
        mediaCodec = null;
    }

    private byte[] createAdtsHeader(int packetLen, int sampleRate, int channels) {
        int totalLen = packetLen + 7;
        int freqIdx;
        switch (sampleRate) {
            case 96000: freqIdx = 0; break;
            case 88200: freqIdx = 1; break;
            case 64000: freqIdx = 2; break;
            case 48000: freqIdx = 3; break;
            case 44100: freqIdx = 4; break;
            case 32000: freqIdx = 5; break;
            case 24000: freqIdx = 6; break;
            case 22050: freqIdx = 7; break;
            case 16000: freqIdx = 8; break;
            case 12000: freqIdx = 9; break;
            case 11025: freqIdx = 10; break;
            case 8000: freqIdx = 11; break;
            case 7350: freqIdx = 12; break;
            default: freqIdx = 4; break;
        }
        byte[] header = new byte[7];
        header[0] = (byte) 0xFF;
        header[1] = (byte) 0xF9; // MPEG-4, No CRC
        header[2] = (byte) (((1 & 0x3) << 6) + (freqIdx << 2) + (channels >> 2));
        header[3] = (byte) (((channels & 3) << 6) + (totalLen >> 11));
        header[4] = (byte) ((totalLen & 0x7FF) >> 3);
        header[5] = (byte) (((totalLen & 7) << 5) + 0x1F);
        header[6] = (byte) 0xFC;
        return header;
    }
}