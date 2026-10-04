#!/usr/bin/env bash
# Installs the Aura Alarm icon + app name into the Android project.
# Run from the flutter_app folder:   bash apply_icon.sh
set -e
cd "$(dirname "$0")"
RES=android/app/src/main/res
MAN=android/app/src/main/AndroidManifest.xml
if [ ! -d "$RES" ] || [ ! -f "$MAN" ]; then
  echo "android/ folder not found here. Run first:  flutter create . --platforms=android,web --org com.robiulhasan"
  exit 1
fi
cp -r android_res/* "$RES"/
sed -i 's/android:label="[^"]*"/android:label="Aura Alarm"/' "$MAN"
echo "Done: logo icon installed and app name set to 'Aura Alarm'."
echo "Next:  flutter clean && flutter build apk --release   (uninstall the old app from the phone first)"
grep -n 'android:label\|android:icon' "$MAN" || true
