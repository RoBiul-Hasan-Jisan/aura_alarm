# Android setup (package: com.robiulhasan.aura_alarm)

1. Copy `google-services.json` from this folder to `android/app/google-services.json`.

2. Add the Google services plugin.
   Newer Flutter projects keep plugins in `android/settings.gradle.kts`:
   ```kotlin
   plugins {
       // ...existing plugins...
       id("com.google.gms.google-services") version "4.4.2" apply false
   }
   ```
   (If your project instead has a root `android/build.gradle.kts` with a `plugins { }` block, add the same line there.)

3. In `android/app/build.gradle.kts`:
   ```kotlin
   plugins {
       id("com.android.application")
       id("kotlin-android")
       id("dev.flutter.flutter-gradle-plugin")
       id("com.google.gms.google-services")   // <- add
   }
   android {
       defaultConfig {
           applicationId = "com.robiulhasan.aura_alarm"
           minSdk = 23                          // Firebase needs 23+
       }
   }
   ```
   You do not need the Firebase BoM `dependencies` block; the Flutter plugins add their own.

4. In `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <application android:usesCleartextTraffic="true" ...>
   ```
   (cleartext lets the emulator call your local http:// API during development)

5. Run:
   flutter clean && flutter pub get && flutter run -d <android-device>

6. App icon and name (what people see after installing)
   **Easiest:** from the `flutter_app` folder run `bash apply_icon.sh`. It copies the ready-made Android icons from
   `android_res/` into the project and sets the app name to `Aura Alarm`. Then `flutter clean && flutter build apk --release`.
   (The manual way, below, does the same thing.)
   ```bash
   flutter pub get
   dart run flutter_launcher_icons      # writes the logo into Android, iOS and web icon folders
   ```
   In `android/app/src/main/AndroidManifest.xml` set the visible name:
   `<application android:label="Aura Alarm" ...>`
   For the browser tab, set `<title>Aura Alarm</title>` in `web/index.html` and `"name"` / `"short_name"`
   to `Aura Alarm` in `web/manifest.json`.
   Then uninstall any old build and run again (`flutter clean && flutter run`) so the new icon shows.

7. Alarm ringing (the `alarm` package: rings with the app closed, vibrates, loops the ringtone)
   a. `android/app/build.gradle.kts`: `compileSdk = 35` (or higher), `minSdk = 23`, and inside `defaultConfig { multiDexEnabled = true }`.
   b. `android/settings.gradle.kts`: Kotlin plugin version must be at least 2.0.0
      (`id("org.jetbrains.kotlin.android") version "2.0.0" apply false`).
   c. `AndroidManifest.xml`, inside `<manifest>` (next to the INTERNET permission):
   ```xml
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
   <uses-permission android:name="android.permission.WAKE_LOCK"/>
   <uses-permission android:name="android.permission.VIBRATE"/>
   <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
   <uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY"/>
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
   ```
   d. First launch: allow **Notifications** and **Alarms & reminders** when asked (the app asks after sign-in).
   e. On Xiaomi / Samsung / Oppo / Huawei phones also turn off battery optimisation for the app
      (Settings > Apps > Aura Alarm > Battery > Unrestricted), otherwise the phone may stop alarms.
   f. Check it works: Alarms tab > the bell button (top right) > lock the phone. It rings in 10 seconds.
