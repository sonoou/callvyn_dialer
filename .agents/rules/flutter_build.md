---
trigger: always_on
---

# Flutter APK Build & Install Rule

- When requested by the user to build and install the APK (`flutter build apk`), ALWAYS run:
  ```bash
  flutter build apk --split-per-abi
  ```
- **NEVER** use `--debug` when building or installing the APK.
