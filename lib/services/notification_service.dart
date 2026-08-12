import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static Future<void> init() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission();

    String? token = await messaging.getToken();

    print("FCM TOKEN = $token");
  }

  static Future<void> sendPush({
    required String token,
    required String title,
    required String body,
  }) async {
    const serverKey = "YOUR_SERVER_KEY";

    await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),

      headers: {
        "Content-Type": "application/json",
        "Authorization": "key=$serverKey",
      },

      body: jsonEncode({
        "to": token,

        "notification": {"title": title, "body": body},

        "priority": "high",
      }),
    );
  }
}
