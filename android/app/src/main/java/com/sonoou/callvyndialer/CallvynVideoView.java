package com.sonoou.callvyndialer;

import android.content.Context;
import android.graphics.SurfaceTexture;
import android.util.Log;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;

import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

public class CallvynVideoView {

    public static class CallvynRemoteVideoPlatformView implements PlatformView, TextureView.SurfaceTextureListener {
        private final TextureView textureView;
        private Surface surface;

        public CallvynRemoteVideoPlatformView(Context context) {
            this.textureView = new TextureView(context);
            this.textureView.setSurfaceTextureListener(this);
        }

        @Override
        public View getView() {
            return textureView;
        }

        @Override
        public void dispose() {
            Log.d("CallvynVideo", "CallvynRemoteVideoPlatformView: dispose");
            CallvynInCallService.setRemoteSurface(null);
            if (surface != null) {
                surface.release();
                surface = null;
            }
        }

        @Override
        public void onSurfaceTextureAvailable(SurfaceTexture surfaceTexture, int width, int height) {
            Log.d("CallvynVideo", "CallvynRemoteVideoPlatformView: onSurfaceTextureAvailable (" + width + " x " + height + ")");
            if (surface != null) {
                surface.release();
            }
            Surface s = new Surface(surfaceTexture);
            surface = s;
            CallvynInCallService.setRemoteSurface(s);
        }

        @Override
        public void onSurfaceTextureSizeChanged(SurfaceTexture surfaceTexture, int width, int height) {
            Log.d("CallvynVideo", "CallvynRemoteVideoPlatformView: onSurfaceTextureSizeChanged (" + width + " x " + height + ")");
            if (surface != null) {
                CallvynInCallService.setRemoteSurface(surface);
            }
        }

        @Override
        public boolean onSurfaceTextureDestroyed(SurfaceTexture surfaceTexture) {
            Log.d("CallvynVideo", "CallvynRemoteVideoPlatformView: onSurfaceTextureDestroyed");
            CallvynInCallService.setRemoteSurface(null);
            if (surface != null) {
                surface.release();
                surface = null;
            }
            return true;
        }

        @Override
        public void onSurfaceTextureUpdated(SurfaceTexture surfaceTexture) {}
    }

    public static class CallvynLocalVideoPlatformView implements PlatformView, TextureView.SurfaceTextureListener {
        private final TextureView textureView;
        private Surface surface;

        public CallvynLocalVideoPlatformView(Context context) {
            this.textureView = new TextureView(context);
            this.textureView.setSurfaceTextureListener(this);
        }

        @Override
        public View getView() {
            return textureView;
        }

        @Override
        public void dispose() {
            Log.d("CallvynVideo", "CallvynLocalVideoPlatformView: dispose");
            CallvynInCallService.setLocalSurface(null);
            if (surface != null) {
                surface.release();
                surface = null;
            }
        }

        @Override
        public void onSurfaceTextureAvailable(SurfaceTexture surfaceTexture, int width, int height) {
            Log.d("CallvynVideo", "CallvynLocalVideoPlatformView: onSurfaceTextureAvailable (" + width + " x " + height + ")");
            if (surface != null) {
                surface.release();
            }
            Surface s = new Surface(surfaceTexture);
            surface = s;
            CallvynInCallService.setLocalSurface(s);
        }

        @Override
        public void onSurfaceTextureSizeChanged(SurfaceTexture surfaceTexture, int width, int height) {
            Log.d("CallvynVideo", "CallvynLocalVideoPlatformView: onSurfaceTextureSizeChanged (" + width + " x " + height + ")");
            if (surface != null) {
                CallvynInCallService.setLocalSurface(surface);
            }
        }

        @Override
        public boolean onSurfaceTextureDestroyed(SurfaceTexture surfaceTexture) {
            Log.d("CallvynVideo", "CallvynLocalVideoPlatformView: onSurfaceTextureDestroyed");
            CallvynInCallService.setLocalSurface(null);
            if (surface != null) {
                surface.release();
                surface = null;
            }
            return true;
        }

        @Override
        public void onSurfaceTextureUpdated(SurfaceTexture surfaceTexture) {}
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
