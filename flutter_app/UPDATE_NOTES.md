# Update notes

Extract this over your existing `flutter_app` folder (merge/replace), then:

    flutter clean
    flutter pub get
    flutter build apk --release

**Uninstall the old app from the phone first.** The app id changed (see below), so Android treats this as a new app.

## What changed
- **App name** is now "Aura Alarm" (Android, web, Windows, Linux window titles).
- **Logo icon** installed: Android launcher (adaptive + round + legacy), web favicon / PWA icons, Windows .ico.
- **AndroidManifest.xml**
  - added the INTERNET permission (without it, release APKs cannot reach the server)
  - added the alarm permissions (wake the phone, vibrate, run in the background, exact alarms, notifications)
- **applicationId / namespace** changed from `com.example.aura_alarm` to `com.robiulhasan.aura_alarm`
  so it matches your Firebase Android app. `MainActivity.kt` moved to the matching package folder.
- **minSdk** is at least 23 (Firebase and the alarm package need it); multiDex enabled.
- **Web manifest / title / theme color** set to the Aura Alarm dark theme.
- Your `lib/` code and your `lib/config.dart` (Render URL) are unchanged.
- Removed the old helper files (`apply_icon.sh`, `android_res/`); everything they did is now applied directly.

## After installing on the phone
1. Open the app and allow **Notifications** and **Alarms & reminders** when asked.
2. Alarms tab > bell icon (top right) > lock the phone. A test alarm rings in 10 seconds.
3. Xiaomi / Samsung / Oppo / Huawei: Settings > Apps > Aura Alarm > Battery > Unrestricted.
