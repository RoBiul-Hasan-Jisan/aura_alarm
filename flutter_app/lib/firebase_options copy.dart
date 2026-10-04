import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase project: 
/// Android values come from google-services.json, web values from the Firebase web app config.
/// (These keys identify the project; they are not secrets. Security comes from Firebase Auth + the backend.)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      if (web.apiKey.startsWith('PASTE') || web.appId.startsWith('PASTE')) {
        throw UnsupportedError(
            'Web Firebase config is missing. Register a Web app in the Firebase console and paste its '
            'apiKey and appId into lib/firebase_options.dart, or run the app on Android instead.');
      }
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Firebase is only configured for Android and Web in this project.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
    storageBucket: '',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey:'',
    appId: '',
    messagingSenderId: '',
    projectId: '',
    authDomain: '',
    storageBucket: '',
  );
}
