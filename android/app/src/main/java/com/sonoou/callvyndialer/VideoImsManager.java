package com.sonoou.callvyndialer;

import android.content.Context;
import android.content.Intent;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.media.MediaCodecInfo;
import android.media.MediaCodecList;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.telecom.Call;
import android.telecom.PhoneAccountHandle;
import android.telecom.TelecomManager;
import android.telecom.VideoProfile;
import android.telephony.SubscriptionManager;
import android.util.Log;
import android.view.Surface;

import java.lang.reflect.Method;
import java.util.List;

public class VideoImsManager {
    private static final String TAG = "VideoImsManager";
    public static VideoImsManager instance;

    // AOSP Telecom & IMS constants for compatibility across all SDK versions
    private static final int CAPABILITY_CAN_UPGRADE_TO_VIDEO = 0x00800000;
    private static final int IMS_CAPABILITY_TYPE_VIDEO = 2; // MmTelFeature.MmTelCapabilities.CAPABILITY_TYPE_VIDEO
    private static final int REGISTRATION_TECH_LTE = 0;    // ImsRegistrationImplBase.REGISTRATION_TECH_LTE
    private static final int REGISTRATION_TECH_IWLAN = 1;  // ImsRegistrationImplBase.REGISTRATION_TECH_IWLAN

    private final Context context;
    private final int subscriptionId;
    private VideoCallEventListener eventListener;
    private boolean isFrontCamera = true;

    public interface VideoCallEventListener {
        void onCallConnected(String callId);
        void onCallProgressing();
        void onCallTerminated(int code, String message);
        void onCallModified(int videoDirection);
        void onUpgradeRequested();
        void onDowngradeRequested();
        void onCameraToggled(String cameraId);
        void onVideoMuted(boolean muted);
        void onError(String message);
    }

    public VideoImsManager(Context context, int subscriptionId) {
        this.context = context.getApplicationContext();
        this.subscriptionId = subscriptionId;
        instance = this;
        Log.d(TAG, "VideoImsManager initialized for subId: " + subscriptionId);
    }

    public void setEventListener(VideoCallEventListener listener) {
        this.eventListener = listener;
    }

    public VideoCallEventListener getEventListener() {
        return eventListener;
    }

    public boolean isVideoCallingCapable() {
        try {
            // 1. Check active telecom call capabilities if call exists
            Call call = CallvynInCallService.activeCall;
            if (call != null) {
                Call.Details details = call.getDetails();
                if (details != null) {
                    int caps = details.getCallCapabilities();
                    boolean canLocalTx = (caps & Call.Details.CAPABILITY_SUPPORTS_VT_LOCAL_TX) != 0;
                    boolean canLocalRx = (caps & Call.Details.CAPABILITY_SUPPORTS_VT_LOCAL_RX) != 0;
                    boolean canLocalBi = (caps & Call.Details.CAPABILITY_SUPPORTS_VT_LOCAL_BIDIRECTIONAL) != 0;
                    boolean canRemoteBi = (caps & Call.Details.CAPABILITY_SUPPORTS_VT_REMOTE_BIDIRECTIONAL) != 0;
                    boolean canUpgrade = (caps & CAPABILITY_CAN_UPGRADE_TO_VIDEO) != 0;
                    if (canLocalTx || canLocalRx || canLocalBi || canRemoteBi || canUpgrade) {
                        return true;
                    }
                }
            }

            // 2. Query framework ImsMmTelManager via reflection (Android 11+ / ImsTestService reference)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    int targetSubId = subscriptionId != 0 ? subscriptionId : SubscriptionManager.getDefaultVoiceSubscriptionId();
                    if (targetSubId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
                        Class<?> imsClass = Class.forName("android.telephony.ims.ImsMmTelManager");
                        Method createMethod = imsClass.getMethod("createForSubscriptionId", int.class);
                        Object imsManager = createMethod.invoke(null, targetSubId);
                        if (imsManager != null) {
                            Method isAvailableMethod = imsClass.getMethod("isAvailable", int.class, int.class);
                            Object isLteVideo = isAvailableMethod.invoke(
                                imsManager,
                                IMS_CAPABILITY_TYPE_VIDEO,
                                REGISTRATION_TECH_LTE
                            );
                            Object isWifiVideo = isAvailableMethod.invoke(
                                imsManager,
                                IMS_CAPABILITY_TYPE_VIDEO,
                                REGISTRATION_TECH_IWLAN
                            );
                            if (Boolean.TRUE.equals(isLteVideo) || Boolean.TRUE.equals(isWifiVideo)) {
                                return true;
                            }
                        }
                    }
                } catch (Throwable ignored) {}
            }

            // 3. Fallback: Query TelecomManager call-capable accounts
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                TelecomManager tm = (TelecomManager) context.getSystemService(Context.TELECOM_SERVICE);
                if (tm != null) {
                    List<PhoneAccountHandle> phoneAccounts = tm.getCallCapablePhoneAccounts();
                    if (phoneAccounts != null && !phoneAccounts.isEmpty()) {
                        return true;
                    }
                }
            }
            return true;
        } catch (Exception e) {
            Log.e(TAG, "isVideoCallingCapable error: " + e.getMessage(), e);
            return false;
        }
    }

    public void placeVideoCall(String phoneNumber) {
        String cleanNumber = phoneNumber.replace(" ", "").trim();
        if (cleanNumber.isEmpty()) {
            if (eventListener != null) {
                eventListener.onError("Phone number is empty");
            }
            return;
        }

        try {
            TelecomManager telecomManager = (TelecomManager) context.getSystemService(Context.TELECOM_SERVICE);
            Uri uri = Uri.fromParts("tel", cleanNumber, null);
            if (telecomManager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Bundle extras = new Bundle();
                extras.putInt(TelecomManager.EXTRA_START_CALL_WITH_VIDEO_STATE, VideoProfile.STATE_BIDIRECTIONAL);
                extras.putInt("android.telecom.extra.START_CALL_WITH_VIDEO_STATE", VideoProfile.STATE_BIDIRECTIONAL);
                extras.putBoolean("android.telecom.extra.START_CALL_WITH_SPEAKERPHONE_ON", true);
                extras.putBoolean("videocall", true);
                extras.putBoolean("com.android.phone.extra.video", true);
                extras.putBoolean("org.codeaurora.extra.VT_CALL", true);
                extras.putBoolean("android.intent.extra.VIDEO_CALL", true);

                // If a specific subId / account handle is needed, assign it
                if (subscriptionId != 0) {
                    try {
                        List<PhoneAccountHandle> accounts = telecomManager.getCallCapablePhoneAccounts();
                        if (accounts != null) {
                            for (PhoneAccountHandle handle : accounts) {
                                String id = handle.getId();
                                if (id != null && (id.contains(String.valueOf(subscriptionId)) || id.contains("sub_" + subscriptionId))) {
                                    extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, handle);
                                    break;
                                }
                            }
                        }
                    } catch (Exception ignored) {}
                }

                telecomManager.placeCall(uri, extras);
                Log.d(TAG, "placeVideoCall initiated via TelecomManager for: " + cleanNumber);
                if (eventListener != null) {
                    eventListener.onCallProgressing();
                }
                return;
            }

            String encodedNumber = Uri.encode(cleanNumber);
            Uri callUri = Uri.parse("tel:" + encodedNumber);
            Intent intent = new Intent(Intent.ACTION_CALL, callUri);
            intent.putExtra(TelecomManager.EXTRA_START_CALL_WITH_VIDEO_STATE, VideoProfile.STATE_BIDIRECTIONAL);
            intent.putExtra("android.telecom.extra.START_CALL_WITH_VIDEO_STATE", 3);
            intent.putExtra("com.android.phone.extra.video", true);
            intent.putExtra("videocall", true);
            intent.putExtra("org.codeaurora.extra.VT_CALL", true);
            intent.putExtra("android.intent.extra.VIDEO_CALL", true);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            if (eventListener != null) {
                eventListener.onCallProgressing();
            }
        } catch (Exception e) {
            Log.e(TAG, "placeVideoCall error: " + e.getMessage(), e);
            if (eventListener != null) {
                eventListener.onError("Failed to place video call: " + e.getMessage());
            }
        }
    }

    public void upgradeToVideo() {
        Call call = CallvynInCallService.activeCall;
        android.telecom.InCallService.VideoCall vCall = null;
        if (call != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            vCall = call.getVideoCall();
        }
        if (vCall == null) {
            vCall = CallvynInCallService.currentVideoCall;
        }

        if (vCall == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            if (eventListener != null) {
                eventListener.onError("No active video call session to upgrade");
            }
            return;
        }

        try {
            CallvynInCallService.syncVideoSession(vCall, context, !isFrontCamera);
            VideoProfile requestProfile = new VideoProfile(
                VideoProfile.STATE_BIDIRECTIONAL,
                VideoProfile.QUALITY_DEFAULT
            );
            vCall.sendSessionModifyRequest(requestProfile);
            Log.d(TAG, "Upgrading to video (sendSessionModifyRequest STATE_BIDIRECTIONAL)");
            if (eventListener != null) {
                eventListener.onUpgradeRequested();
            }
        } catch (Exception e) {
            Log.e(TAG, "upgradeToVideo error: " + e.getMessage(), e);
            if (eventListener != null) {
                eventListener.onError("Failed to upgrade to video: " + e.getMessage());
            }
        }
    }

    public void downgradeToAudio() {
        Call call = CallvynInCallService.activeCall;
        android.telecom.InCallService.VideoCall vCall = null;
        if (call != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            vCall = call.getVideoCall();
        }
        if (vCall == null) {
            vCall = CallvynInCallService.currentVideoCall;
        }
        if (vCall == null) return;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                VideoProfile audioProfile = new VideoProfile(
                    VideoProfile.STATE_AUDIO_ONLY,
                    VideoProfile.QUALITY_DEFAULT
                );
                vCall.sendSessionModifyRequest(audioProfile);
                Log.d(TAG, "Downgrading to audio (sendSessionModifyRequest STATE_AUDIO_ONLY)");
                if (eventListener != null) {
                    eventListener.onDowngradeRequested();
                }
            } catch (Exception e) {
                Log.e(TAG, "downgradeToAudio error: " + e.getMessage(), e);
                if (eventListener != null) {
                    eventListener.onError("Failed to downgrade to audio: " + e.getMessage());
                }
            }
        }
    }

    public void toggleCamera() {
        isFrontCamera = !isFrontCamera;
        boolean useBack = !isFrontCamera;
        CallvynInCallService.switchCamera(useBack);
        String cameraId = getCameraId(context, useBack);
        Log.d(TAG, "Camera toggled to: " + cameraId + " (useBack=" + useBack + ")");
        if (eventListener != null) {
            eventListener.onCameraToggled(cameraId);
        }
    }

    public static String getCameraId(Context context, boolean useBack) {
        try {
            if (context != null) {
                CameraManager cm = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);
                if (cm != null) {
                    int targetFacing = useBack ? CameraCharacteristics.LENS_FACING_BACK : CameraCharacteristics.LENS_FACING_FRONT;
                    for (String id : cm.getCameraIdList()) {
                        CameraCharacteristics cc = cm.getCameraCharacteristics(id);
                        Integer facing = cc.get(CameraCharacteristics.LENS_FACING);
                        if (facing != null && facing == targetFacing) {
                            return id;
                        }
                    }
                }
            }
        } catch (Exception ignored) {}
        return useBack ? "0" : "1";
    }

    public void setVideoMuted(boolean muted) {
        Call call = CallvynInCallService.activeCall;
        android.telecom.InCallService.VideoCall vCall = null;
        if (call != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            vCall = call.getVideoCall();
        }
        if (vCall == null) {
            vCall = CallvynInCallService.currentVideoCall;
        }
        if (vCall == null) return;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                int targetState = muted ? VideoProfile.STATE_RX_ENABLED : VideoProfile.STATE_BIDIRECTIONAL;
                VideoProfile profile = new VideoProfile(targetState, VideoProfile.QUALITY_DEFAULT);
                vCall.sendSessionModifyRequest(profile);
                Log.d(TAG, "Video muted=" + muted + ", targetState=" + targetState);
                if (eventListener != null) {
                    eventListener.onVideoMuted(muted);
                }
            } catch (Exception e) {
                Log.e(TAG, "setVideoMuted error: " + e.getMessage(), e);
            }
        }
    }

    public void endCall() {
        try {
            Call call = CallvynInCallService.activeCall;
            if (call != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                call.disconnect();
            }
            Log.d(TAG, "Video call ended by user");
        } catch (Exception e) {
            Log.e(TAG, "endCall error: " + e.getMessage(), e);
        }
    }

    public boolean checkVideoCodecSupport() {
        try {
            MediaCodecList mediaCodecList = new MediaCodecList(MediaCodecList.REGULAR_CODECS);
            boolean h264Available = false;
            for (MediaCodecInfo info : mediaCodecList.getCodecInfos()) {
                if (info.isEncoder()) {
                    String name = info.getName().toLowerCase();
                    if (name.contains("avc") || name.contains("h264")) {
                        h264Available = true;
                        Log.d(TAG, "H.264 / AVC encoder available: " + info.getName());
                        break;
                    }
                }
            }
            return h264Available;
        } catch (Exception e) {
            Log.e(TAG, "checkVideoCodecSupport error: " + e.getMessage(), e);
            return true;
        }
    }

    public void setDisplaySurface(Surface surface) {
        if (VideoProviderWrapper.instance != null) {
            VideoProviderWrapper.instance.setDisplaySurface(surface);
        }
        CallvynInCallService.setRemoteSurface(surface);
    }

    public void setPreviewSurface(Surface surface) {
        if (VideoProviderWrapper.instance != null) {
            VideoProviderWrapper.instance.setPreviewSurface(surface);
        }
        CallvynInCallService.setLocalSurface(surface);
    }

    public void setCamera(String cameraId) {
        if (VideoProviderWrapper.instance != null) {
            VideoProviderWrapper.instance.setCamera(cameraId);
        } else {
            CallvynInCallService.switchCamera("0".equals(cameraId));
        }
    }

    public int getCurrentVideoState() {
        Call call = CallvynInCallService.activeCall;
        if (call != null && call.getDetails() != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return call.getDetails().getVideoState();
        }
        return VideoProfile.STATE_AUDIO_ONLY;
    }
}
