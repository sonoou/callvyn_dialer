package com.sonoou.callvyndialer;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;
import androidx.core.app.NotificationCompat;

public class CallvynForegroundService extends Service {
    public static final String CHANNEL_ID = "callvyn_service_channel";
    public static final int NOTIFICATION_ID = 1001;

    public static void start(Context context) {
        try {
            Intent intent = new Intent(context, CallvynForegroundService.class);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent);
            } else {
                context.startService(intent);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
        Notification notification = buildServiceNotification();
        startForegroundServiceCompat(notification);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Notification notification = buildServiceNotification();
        startForegroundServiceCompat(notification);
        return START_STICKY;
    }

    private void startForegroundServiceCompat(Notification notification) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                int serviceType = 0;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    serviceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL |
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE;
                } else {
                    serviceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL;
                }
                startForeground(NOTIFICATION_ID, notification, serviceType);
            } else {
                startForeground(NOTIFICATION_ID, notification);
            }
        } catch (Exception e) {
            try {
                startForeground(NOTIFICATION_ID, notification);
            } catch (Exception e2) {
                e2.printStackTrace();
            }
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        try {
            Intent restartIntent = new Intent(getApplicationContext(), BootReceiver.class);
            restartIntent.setAction(Intent.ACTION_MY_PACKAGE_REPLACED);
            sendBroadcast(restartIntent);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Callvyn Phone Service",
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Keeps Callvyn Dialer active for incoming and outgoing calls");
            channel.setShowBadge(false);
            channel.setLockscreenVisibility(Notification.VISIBILITY_SECRET);

            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }

    private Notification buildServiceNotification() {
        Intent launchIntent = new Intent(this, MainActivity.class);
        launchIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);

        PendingIntent pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
                : PendingIntent.FLAG_UPDATE_CURRENT
        );

        return new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Callvyn Dialer Active")
            .setContentText("Ready for incoming and outgoing calls")
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFF02BC58)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .build();
    }
}
