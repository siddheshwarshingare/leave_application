import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _checkingUpdate = false;

  // IMPORTANT:
  // Replace this with the package/applicationId from android/app/build.gradle
  // or android/app/build.gradle.kts
  static const String packageName = 'YOUR_PACKAGE_NAME';

  @override
  void initState() {
    super.initState();

    _startSplash();
  }

  // ============================================================
  // SPLASH FLOW
  // ============================================================

  Future<void> _startSplash() async {
    await Future.delayed(
      const Duration(seconds: 1),
    );

    if (!mounted) return;

    final bool updateRequired =
        await _checkUpdateRequired();

    if (!mounted) return;

    if (updateRequired) {
      debugPrint(
        'UPDATE REQUIRED -> SHOWING DIALOG',
      );

      _showUpdateDialog();

      // IMPORTANT:
      // Do NOT navigate to nextScreen here.
      return;
    }

    debugPrint(
      'NO UPDATE REQUIRED -> NEXT SCREEN',
    );

    _goToNextScreen();
  }

  // ============================================================
  // CHECK FIREBASE
  // ============================================================

  Future<bool> _checkUpdateRequired() async {
    if (_checkingUpdate) {
      return false;
    }

    _checkingUpdate = true;

    try {
      // --------------------------------------------------------
      // INSTALLED APP VERSION
      // --------------------------------------------------------

      final PackageInfo packageInfo =
          await PackageInfo.fromPlatform();

      final String currentVersion =
          packageInfo.version.trim();

      final String buildNumber =
          packageInfo.buildNumber.trim();

      debugPrint(
        'INSTALLED VERSION = $currentVersion',
      );

      debugPrint(
        'BUILD NUMBER = $buildNumber',
      );

      // --------------------------------------------------------
      // FIREBASE
      // --------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>>
          snapshot =
          await FirebaseFirestore.instance
              .collection('app_config')
              .doc('app_update')
              .get();

      if (!snapshot.exists) {
        debugPrint(
          'app_config/app_update NOT FOUND',
        );

        return false;
      }

      final Map<String, dynamic>? data =
          snapshot.data();

      if (data == null) {
        return false;
      }

      // --------------------------------------------------------
      // UPDATE REQUIRED
      // --------------------------------------------------------

      final bool updateRequired =
          data['updateRequired'] == true;

      String latestVersion =
          data['latestVersion']
                  ?.toString()
                  .trim() ??
              '';

      // Remove accidental quotes from Firebase
      latestVersion =
          latestVersion.replaceAll('"', '');

      debugPrint(
        'CURRENT APP VERSION = $currentVersion',
      );

      debugPrint(
        'Firebase updateRequired = $updateRequired',
      );

      debugPrint(
        'Firebase latestVersion = $latestVersion',
      );

      // --------------------------------------------------------
      // ADMIN HAS DISABLED UPDATE
      // --------------------------------------------------------

      if (!updateRequired) {
        return false;
      }

      // --------------------------------------------------------
      // NO VERSION
      // --------------------------------------------------------

      if (latestVersion.isEmpty) {
        debugPrint(
          'Update enabled but latestVersion is empty',
        );

        return true;
      }

      // --------------------------------------------------------
      // VERSION COMPARISON
      // --------------------------------------------------------

      final int comparison =
          _compareVersions(
        currentVersion,
        latestVersion,
      );

      debugPrint(
        'Version comparison = $comparison',
      );

      if (comparison < 0) {
        debugPrint(
          'UPDATE REQUIRED: '
          '$currentVersion -> $latestVersion',
        );

        return true;
      }

      debugPrint(
        'Current version is already up to date.',
      );

      return false;
    } catch (e, stackTrace) {
      debugPrint(
        'Error checking app update: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      // If Firebase fails,
      // allow the user to continue.
      return false;
    } finally {
      _checkingUpdate = false;
    }
  }

  // ============================================================
  // VERSION COMPARISON
  // ============================================================

  int _compareVersions(
    String currentVersion,
    String latestVersion,
  ) {
    final List<int> current =
        _parseVersion(currentVersion);

    final List<int> latest =
        _parseVersion(latestVersion);

    final int maxLength =
        current.length > latest.length
            ? current.length
            : latest.length;

    for (int i = 0; i < maxLength; i++) {
      final int currentPart =
          i < current.length
              ? current[i]
              : 0;

      final int latestPart =
          i < latest.length
              ? latest[i]
              : 0;

      if (currentPart < latestPart) {
        return -1;
      }

      if (currentPart > latestPart) {
        return 1;
      }
    }

    return 0;
  }

  // ============================================================
  // PARSE VERSION
  // ============================================================

  List<int> _parseVersion(
    String version,
  ) {
    return version
        .split('.')
        .map(
          (part) =>
              int.tryParse(
                part.replaceAll(
                  RegExp(r'[^0-9]'),
                  '',
                ),
              ) ??
              0,
        )
        .toList();
  }

  // ============================================================
  // UPDATE DIALOG
  // ============================================================

  void _showUpdateDialog() {
    if (!mounted) return;

    debugPrint(
      'SHOWING UPDATE DIALOG',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text(
              'Update Available',
            ),
            content: const Text(
              'A new version of the app is available. '
              'Please update the app to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _openPlayStore();
                },
                child: const Text(
                  'Update Now',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // OPEN PLAY STORE
  // ============================================================

  Future<void> _openPlayStore() async {
    // ----------------------------------------------------------
    // PLAY STORE APP URL
    // ----------------------------------------------------------

    final Uri playStoreAppUrl = Uri.parse(
      'market://details?id=$packageName',
    );

    // ----------------------------------------------------------
    // PLAY STORE WEB URL
    // ----------------------------------------------------------

    final Uri playStoreWebUrl = Uri.parse(
      'https://play.google.com/store/apps/details?id=$packageName',
    );

    try {
      // First try opening Google Play app
      final bool openedPlayStore =
          await launchUrl(
        playStoreAppUrl,
        mode: LaunchMode.externalApplication,
      );

      if (openedPlayStore) {
        debugPrint(
          'Opened Google Play Store app',
        );

        return;
      }
    } catch (e) {
      debugPrint(
        'Could not open Play Store app: $e',
      );
    }

    // ----------------------------------------------------------
    // FALLBACK TO BROWSER
    // ----------------------------------------------------------

    try {
      final bool openedBrowser =
          await launchUrl(
        playStoreWebUrl,
        mode: LaunchMode.externalApplication,
      );

      if (openedBrowser) {
        debugPrint(
          'Opened Google Play Store in browser',
        );

        return;
      }
    } catch (e) {
      debugPrint(
        'Could not open Play Store web: $e',
      );
    }

    // ----------------------------------------------------------
    // NOTHING WORKED
    // ----------------------------------------------------------

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to open Google Play Store.',
        ),
      ),
    );
  }

  // ============================================================
  // NORMAL NAVIGATION
  // ============================================================

  void _goToNextScreen() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => widget.nextScreen,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FA),
      body: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/MobApp.png',
              width: 800,
              height: 800,
            ),

            const Text(
              'Leave Application',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
