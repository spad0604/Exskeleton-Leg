import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } on Object catch (error) {
    if (kDebugMode) {
      debugPrint('Firebase background init failed: $error');
    }
  }
}

class FcmService {
  FcmService._();

  static String? _token;
  static String? get token => _token;

  static Future<String?> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('Firebase init skipped: ${error.message}');
      }
      return null;
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Firebase init skipped: $error');
      }
      return null;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();
    _token = token;
    if (kDebugMode) {
      debugPrint('FCM token: $token');
    }

    messaging.onTokenRefresh.listen((token) {
      _token = token;
      if (kDebugMode) {
        debugPrint('FCM token refreshed: $token');
      }
    });

    FirebaseMessaging.onMessage.listen((message) {
      if (kDebugMode) {
        debugPrint('Foreground FCM: ${message.messageId}');
      }
    });

    return token;
  }
}
