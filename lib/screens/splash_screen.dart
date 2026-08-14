import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 1), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.nextScreen),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your logo/image
            Image.asset('assets/MobApp.png', width: 800, height: 800),

            // const SizedBox(height: 30),

            //  const SizedBox(height: 20),
            const Text(
              "Leave Application",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
