import 'package:firebase_core/firebase_core.dart';

// TODO: Replace with actual values from your Firebase configuration
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // You'll need to replace these values with the ones from your
    // google-services.json and GoogleService-Info.plist files
    return const FirebaseOptions(
      apiKey: 'AIzaSyCTbiyref1uKdcYsrYKC0aUjmI2ZujIJs8',
      appId: '1:330678366815:android:e7a99f693e21b300fc61ea',
      messagingSenderId: '330678366815',
      projectId: 'tickify-db',
      storageBucket: 'tickify-db.firebasestorage.app',
    );
  }
}
