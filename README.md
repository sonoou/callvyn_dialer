# Callvyn Dialer (Flutter + Pure Java)

A fast, responsive, and MIUI-styled dialer application built using **Flutter** for the frontend UI and **100% pure Java** for the native Android telephony integration.

---

## 🚀 Working Features

- **Voice Calling**:
  - Outgoing native voice call placement with automatic SIM slot detection (Dual SIM support).
  - Incoming call full-screen overlay for locked devices and background states.
  - Custom MIUI-styled heads-up incoming call notifications with fast Answer / Reject actions.
  - Active call management: Mute, Speaker, Call Hold/Unhold, and Live In-Call Timer.
  - Interactive DTMF dialpad with audio feedback during active calls.
- **Native Telecom Video Calling (ViLTE & Carrier IMS)**:
  - Direct native video calling placement with TelecomManager `VideoProfile.STATE_BIDIRECTIONAL`.
  - In-call mid-session seamless upgrade / downgrade between Voice and Video calls.
  - Hardware camera preview (PIP local view) and full-screen remote video rendering via native `TextureView` platform surfaces.
  - Dynamic front/back camera detection and switching during video calls.
  - IMS Capability detection based on Android `ImsMmTelManager` standards (LTE / IWLAN / Cross-SIM).
- **Call Logs & Contacts**:
  - Full call history view with call types (incoming, outgoing, missed, rejected).
  - Fast search and direct contact dialer.
  - Single and bulk call log deletion.
  - Contact vCard and text sharing.
- **Call Recording Engine**:
  - **With Root Access (`su`)**: Full two-way crystal-clear voice call recording enabled by granting privileged internal audio permissions (`CAPTURE_AUDIO_OUTPUT`, `MODIFY_PHONE_STATE`) and attaching hardware AEC (Acoustic Echo Canceler) + AAC ADTS encoding.
  - **Without Root Access**: On Android 10+ devices, third-party apps are restricted by Android OS security policies from capturing internal call audio streams directly. Full two-way call recording without root is only possible if the app is installed as a **System App** (`/system/priv-app/`). For non-rooted standard app installations, recording uses the standard microphone stream fallback.
- **In-Call Utilities & Notes**:
  - Call Notes: write, save, export, and share notes taken during live calls.
- **System Integration**:
  - Default dialer role management and fallback handling.
  - System wallpaper extraction for background styling.
  - System ringtone and audio preview.
  - Direct Boot and Background Foreground Service for 24/7 call readiness.

---

## 🔮 Upcoming Feature Updates

- **Smart Caller Identification**: Built-in phone number identification and spam protection.
- **Cloud Backup & Sync**: Cloud synchronization for call history and call notes.
- **Advanced Theme Customization**: Custom colors, custom fonts, and dark mode accents.

---

## 🛠️ Architecture & Tech Stack

- **Frontend**: Flutter (Dart)
- **Native Android**: Pure Java (`android/app/src/main/java/com/sonoou/callvyndialer/`)
  - `MainActivity.java`: Flutter MethodChannel bridge & device controllers.
  - `CallvynInCallService.java`: Android Telecom `InCallService` lifecycle management.
  - `CallActionReceiver.java`: BroadcastReceiver for notification actions.
  - `CallvynForegroundService.java`: Persistent foreground service.
  - `CallvynLogger.java`: High-performance background logging system.
- **Target SDK**: Android 14+ (API 34/35/37) with Direct Boot support.

---

## 📦 Build & Installation

To build the release split APKs:

```bash
flutter build apk --split-per-abi
```
