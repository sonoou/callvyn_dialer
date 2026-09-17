package com.sonoou.callvyndialer;

import android.content.Context;
import android.os.Build;
import android.os.Environment;
import android.util.Log;

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class CallvynLogger {
    private static final String TAG = "CallvynLogger";
    private static final ExecutorService executor = Executors.newSingleThreadExecutor();
    private static File logFile = null;
    private static Context appContext = null;

    public static void init(Context context) {
        appContext = context.getApplicationContext();
        setupLogFile();
        setupUncaughtExceptionHandler();
        i(TAG, "CallvynLogger initialized. Target file: " + (logFile != null ? logFile.getAbsolutePath() : "null"));
    }

    private static synchronized void setupLogFile() {
        try {
            String dateStr = new SimpleDateFormat("d_MMM_yy_hhmm_a", Locale.US).format(new Date())
                .replace(" ", "_")
                .toUpperCase(Locale.US);
            String fileName = dateStr + ".txt";

            List<File> candidateDirs = Arrays.asList(
                new File("/sdcard/callvyn_dialer"),
                new File(Environment.getExternalStorageDirectory(), "callvyn_dialer"),
                new File(appContext != null ? appContext.getExternalFilesDir(null) : null, "callvyn_dialer")
            );

            for (File dir : candidateDirs) {
                try {
                    if (dir != null) {
                        if (!dir.exists()) {
                            dir.mkdirs();
                        }
                        File testFile = new File(dir, fileName);
                        if (!testFile.exists()) {
                            testFile.createNewFile();
                        }
                        if (testFile.canWrite()) {
                            logFile = testFile;
                            Log.d(TAG, "Successfully selected log file: " + testFile.getAbsolutePath());
                            break;
                        }
                    }
                } catch (Exception e) {
                    if (dir != null) {
                        Log.w(TAG, "Cannot write to " + dir.getAbsolutePath() + ": " + e.getMessage());
                    }
                }
            }

            if (logFile != null && logFile.length() == 0L) {
                appendLine("==================================================");
                appendLine("CALLVYN DIALER SYSTEM & ERROR LOG");
                appendLine("Session Started: " + new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(new Date()));
                appendLine("Device: " + Build.MANUFACTURER + " " + Build.MODEL + " (Android " + Build.VERSION.RELEASE + ", SDK " + Build.VERSION.SDK_INT + ")");
                appendLine("==================================================\n");
            }
        } catch (Exception e) {
            Log.e(TAG, "setupLogFile error: " + e.getMessage(), e);
        }
    }

    private static void setupUncaughtExceptionHandler() {
        final Thread.UncaughtExceptionHandler defaultHandler = Thread.getDefaultUncaughtExceptionHandler();
        Thread.setDefaultUncaughtExceptionHandler((thread, throwable) -> {
            e("UNCAUGHT_CRASH", "FATAL EXCEPTION in thread " + thread.getName() + ": " + throwable.getMessage(), throwable);
            if (defaultHandler != null) {
                defaultHandler.uncaughtException(thread, throwable);
            }
        });
    }

    public static void v(String tag, String message) {
        log("VERBOSE", tag, message, null);
    }

    public static void d(String tag, String message) {
        log("DEBUG", tag, message, null);
    }

    public static void i(String tag, String message) {
        log("INFO", tag, message, null);
    }

    public static void w(String tag, String message) {
        log("WARN", tag, message, null);
    }

    public static void w(String tag, String message, Throwable throwable) {
        log("WARN", tag, message, throwable);
    }

    public static void e(String tag, String message) {
        log("ERROR", tag, message, null);
    }

    public static void e(String tag, String message, Throwable throwable) {
        log("ERROR", tag, message, throwable);
    }

    public static void logError(String tag, String message, String stackTrace) {
        String time = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(new Date());
        String formatted = "[" + time + "] [ERROR] [" + tag + "]: " + message +
            (stackTrace != null && !stackTrace.isEmpty() ? "\nStack:\n" + stackTrace : "");
        Log.e(tag, message);
        appendLine(formatted);
    }

    private static void log(String level, String tag, String message, Throwable throwable) {
        String time = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(new Date());
        StringBuilder formatted = new StringBuilder("[" + time + "] [" + level + "] [" + tag + "]: " + message);
        if (throwable != null) {
            StringWriter sw = new StringWriter();
            throwable.printStackTrace(new PrintWriter(sw));
            formatted.append("\nStack:\n").append(sw);
        }

        switch (level) {
            case "VERBOSE":
                if (throwable != null) Log.v(tag, message, throwable);
                else Log.v(tag, message);
                break;
            case "DEBUG":
                if (throwable != null) Log.d(tag, message, throwable);
                else Log.d(tag, message);
                break;
            case "INFO":
                if (throwable != null) Log.i(tag, message, throwable);
                else Log.i(tag, message);
                break;
            case "WARN":
                if (throwable != null) Log.w(tag, message, throwable);
                else Log.w(tag, message);
                break;
            case "ERROR":
                if (throwable != null) Log.e(tag, message, throwable);
                else Log.e(tag, message);
                break;
        }

        appendLine(formatted.toString());
    }

    private static void appendLine(final String text) {
        executor.execute(() -> {
            try {
                if (logFile == null || !logFile.exists()) {
                    setupLogFile();
                }
                if (logFile == null) return;
                try (FileWriter writer = new FileWriter(logFile, true)) {
                    writer.write(text + "\n");
                    writer.flush();
                }
            } catch (Exception e) {
                Log.e(TAG, "Error writing to log file: " + e.getMessage(), e);
            }
        });
    }

    public static String getLogFilePath() {
        return logFile != null ? logFile.getAbsolutePath() : null;
    }
}
