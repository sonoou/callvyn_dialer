package com.sonoou.callvyndialer;

import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.telecom.Call;

public class CallActionReceiver extends BroadcastReceiver {
    public static final String ACTION_ANSWER = "com.sonoou.callvyndialer.ACTION_ANSWER_CALL";
    public static final String ACTION_REJECT = "com.sonoou.callvyndialer.ACTION_REJECT_CALL";
    public static final String ACTION_END_CALL = "com.sonoou.callvyndialer.ACTION_END_CALL";
    public static final String ACTION_TOGGLE_HOLD = "com.sonoou.callvyndialer.ACTION_TOGGLE_HOLD";
    public static final String ACTION_TOGGLE_SPEAKER = "com.sonoou.callvyndialer.ACTION_TOGGLE_SPEAKER";

    @Override
    public void onReceive(Context context, Intent intent) {
        String receivedAction = intent.getAction();
        NotificationManager notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);

        if (receivedAction == null) return;

        switch (receivedAction) {
            case ACTION_ANSWER:
                if (notificationManager != null) {
                    notificationManager.cancel(CallvynInCallService.NOTIFICATION_INCOMING_ID);
                }
                try {
                    boolean isVid = CallvynInCallService.isCallVideo(CallvynInCallService.activeCall);
                    CallvynInCallService.answerCall(isVid);
                    Intent launchIntent = new Intent(context, MainActivity.class);
                    launchIntent.setAction(Intent.ACTION_MAIN);
                    launchIntent.addCategory(Intent.CATEGORY_LAUNCHER);
                    launchIntent.addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK |
                        Intent.FLAG_ACTIVITY_CLEAR_TOP |
                        Intent.FLAG_ACTIVITY_SINGLE_TOP |
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                    );
                    launchIntent.putExtra("is_incoming", true);
                    String incomingNumber = "";
                    if (CallvynInCallService.activeCall != null &&
                        CallvynInCallService.activeCall.getDetails() != null &&
                        CallvynInCallService.activeCall.getDetails().getHandle() != null) {
                        incomingNumber = CallvynInCallService.activeCall.getDetails().getHandle().getSchemeSpecificPart();
                    }
                    launchIntent.putExtra("incoming_number", incomingNumber);
                    context.startActivity(launchIntent);
                } catch (Exception e) {
                    e.printStackTrace();
                }
                break;

            case ACTION_REJECT:
                if (notificationManager != null) {
                    notificationManager.cancel(CallvynInCallService.NOTIFICATION_INCOMING_ID);
                }
                try {
                    Call activeCall = CallvynInCallService.activeCall;
                    if (activeCall != null) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            activeCall.reject(false, null);
                        } else {
                            activeCall.disconnect();
                        }
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
                break;

            case ACTION_END_CALL:
                if (notificationManager != null) {
                    notificationManager.cancel(CallvynInCallService.NOTIFICATION_ONGOING_ID);
                }
                try {
                    Call activeCall = CallvynInCallService.activeCall;
                    if (activeCall != null) {
                        activeCall.disconnect();
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
                break;

            case ACTION_TOGGLE_HOLD:
                try {
                    Call activeCall = CallvynInCallService.activeCall;
                    if (activeCall != null) {
                        if (activeCall.getState() == Call.STATE_HOLDING) {
                            activeCall.unhold();
                        } else if (activeCall.getState() == Call.STATE_ACTIVE) {
                            activeCall.hold();
                        }
                    }
                    if (CallvynInCallService.instance != null) {
                        CallvynInCallService.instance.updateOngoingCallNotification();
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
                break;

            case ACTION_TOGGLE_SPEAKER:
                try {
                    CallvynInCallService service = CallvynInCallService.instance;
                    if (service != null) {
                        boolean isSpeaker = service.isSpeakerOn();
                        service.setCallSpeaker(!isSpeaker);
                        service.updateOngoingCallNotification();
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
                break;
        }
    }
}
