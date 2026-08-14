import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:leave_application/screens/admin_leave_screen.dart';
import 'package:leave_application/screens/dashboard_screen.dart';
import 'package:leave_application/screens/login_screen.dart';
import 'package:leave_application/screens/splash_screen.dart';
import 'package:leave_application/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

Future<Widget> checkLogin() async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    bool isLoggedIn = prefs.getBool("isLoggedIn") ?? false;

    if (isLoggedIn) {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        String role = userDoc['role'].toString().toLowerCase();

        if (role == "admin") {
          return const AdminLeaveScreen();
        }

        return const DashboardScreen();
      }
    }
  } catch (e) {
    print("CHECK LOGIN ERROR = $e");
  }

  return const LoginScreen();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.init();

  Widget screen = await checkLogin();

  runApp(MyApp(screen: screen));
}

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   await NotificationService.init();
//   runApp(const MyApp());
// }

class MyApp extends StatelessWidget {
  final Widget screen;

  const MyApp({super.key, required this.screen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(nextScreen: screen),
    );
  }
}
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,

//       home: const LoginScreen(),
//     );
//   }
// }
