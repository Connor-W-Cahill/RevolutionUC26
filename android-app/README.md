# Android Migration

This Android app lives in `android-app/` and does not modify or replace the existing iOS app in `CortisolTracker/`.

## Stack

- Kotlin
- Jetpack Compose
- Firebase Auth
- Firestore
- Firebase Functions

## Security Notes

- `google-services.json` is intentionally not committed. Add it to `app/google-services.json`.
- `PRESAGE_API_KEY` is not committed. If you later wire an Android Presage SDK, provide it through `local.properties` or an environment variable.
- `allowBackup` is disabled in the manifest.
- The Android port uses Firebase callable functions for friend requests instead of the older direct-write iOS helper.

## Current Measurement Path

The iOS app uses `SmartSpectraSwiftSDK`, which is not portable to Android from this repo. The Android app isolates measurement behind `MeasurementProvider` and currently uses a secure demo provider so the rest of the app can run without hardcoded secrets or a missing proprietary SDK.

Replace `DemoMeasurementProvider` in `app/src/main/kotlin/com/revolutionuc/cortisoltracker/android/Data.kt` with the Android Presage implementation when that SDK is available.

## Setup

1. Install Android Studio / Android SDK and JDK 17+.
2. Add `app/google-services.json`.
3. Optionally add `PRESAGE_API_KEY=...` to `local.properties`.
4. Open `android-app/` in Android Studio and sync Gradle.
