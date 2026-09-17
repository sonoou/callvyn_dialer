package com.sonoou.callvyndialer;

import android.content.Context;
import android.util.Log;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;

import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

public class CallvynVideoView {

    public static class CallvynRemoteVideoPlatformView implements PlatformView, SurfaceHolder.Callback {
        private final SurfaceView surfaceView;
        private Surface surface;

        public CallvynRemoteVideoPlatformView(Context context) {
            this.surfaceView = new SurfaceView(context);
            this.surfaceView.getHolder().addCallback(this);
            Surface s = this.surfaceView.getHolder().getSurface();
            if (s != null && s.isValid()) {
                this.surface = s;
                Log.d("CallvynVideo", "CallvynRemoteVideoPlatformView: initial surface valid " + s);
                CallvynInCallService.setRemoteSurface(s);
            }
        }

        @Override
        public View getView() {
            return surfaceView;
        }

        @Override
        public void dispose() {
            Log.d("CallvynVideo", "CallvynRemoteVideoPlatformView: dispose");
            CallvynInCallService.setRemoteSurface(null);
            surface = null;
        }

        @Override
        public void surfaceCreated(SurfaceHolder holder) {
            Surface s = holder.getSurface();
            Log.d("CallvynVideo", "CallvynRemoteVideoPlatformView: surfaceCreated " + s);
            this.surface = s;
            CallvynInCallService.setRemoteSurface(s);
        }

        @Override
        public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
            Surface s = holder.getSurface();
            Log.d("CallvynVideo", "CallvynRemoteVideoPlatformView: surfaceChanged (" + width + "x" + height + ") " + s);
            this.surface = s;
            CallvynInCallService.setRemoteSurface(s);
        }

        @Override
        public void surfaceDestroyed(SurfaceHolder holder) {
            Log.d("CallvynVideo", "CallvynRemoteVideoPlatformView: surfaceDestroyed");
            CallvynInCallService.setRemoteSurface(null);
            this.surface = null;
        }
    }

    public static class CallvynLocalVideoPlatformView implements PlatformView, SurfaceHolder.Callback {
        private final SurfaceView surfaceView;
        private Surface surface;

        public CallvynLocalVideoPlatformView(Context context) {
            this.surfaceView = new SurfaceView(context);
            this.surfaceView.setZOrderMediaOverlay(true);
            this.surfaceView.getHolder().addCallback(this);
            Surface s = this.surfaceView.getHolder().getSurface();
            if (s != null && s.isValid()) {
                this.surface = s;
                Log.d("CallvynVideo", "CallvynLocalVideoPlatformView: initial surface valid " + s);
                CallvynInCallService.setLocalSurface(s);
            }
        }

        @Override
        public View getView() {
            return surfaceView;
        }

        @Override
        public void dispose() {
            Log.d("CallvynVideo", "CallvynLocalVideoPlatformView: dispose");
            CallvynInCallService.setLocalSurface(null);
            surface = null;
        }

        @Override
        public void surfaceCreated(SurfaceHolder holder) {
            Surface s = holder.getSurface();
            Log.d("CallvynVideo", "CallvynLocalVideoPlatformView: surfaceCreated " + s);
            this.surface = s;
            CallvynInCallService.setLocalSurface(s);
        }

        @Override
        public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
            Surface s = holder.getSurface();
            Log.d("CallvynVideo", "CallvynLocalVideoPlatformView: surfaceChanged (" + width + "x" + height + ") " + s);
            this.surface = s;
            CallvynInCallService.setLocalSurface(s);
        }

        @Override
        public void surfaceDestroyed(SurfaceHolder holder) {
            Log.d("CallvynVideo", "CallvynLocalVideoPlatformView: surfaceDestroyed");
            CallvynInCallService.setLocalSurface(null);
            this.surface = null;
        }
    }

    public static class CallvynRemoteVideoViewFactory extends PlatformViewFactory {
        public CallvynRemoteVideoViewFactory() {
            super(StandardMessageCodec.INSTANCE);
        }

        @Override
        public PlatformView create(Context context, int viewId, Object args) {
            return new CallvynRemoteVideoPlatformView(context);
        }
    }

    public static class CallvynLocalVideoViewFactory extends PlatformViewFactory {
        public CallvynLocalVideoViewFactory() {
            super(StandardMessageCodec.INSTANCE);
        }

        @Override
        public PlatformView create(Context context, int viewId, Object args) {
            return new CallvynLocalVideoPlatformView(context);
        }
    }
}
