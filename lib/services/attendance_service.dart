import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class AttendanceService {
  static const double officeLat = 18.548169882550805;
  static const double officeLng = 73.7684216761013;
  static const int allowedRadius = 150;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String _today() {
    final now = DateTime.now();

    return "${now.year}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')}";
  }

  static Future<DocumentReference<Map<String, dynamic>>>
  _getAttendanceDocument() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final uid = user.uid;
    final date = _today();

    final query = await _firestore
        .collection("attendance")
        .where("uid", isEqualTo: uid)
        .where("date", isEqualTo: date)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.reference;
    }

    return _firestore.collection("attendance").doc(uid);
  }

  static Future<void> _addPunch(String type) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final attendanceRef = await _getAttendanceDocument();

    final now = DateTime.now();

    await attendanceRef.set({
      "uid": user.uid,
      "employeeName": user.displayName ?? "",
      "date": _today(),
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await attendanceRef.collection("punches").add({
      "type": type,
      "time": Timestamp.fromDate(now),
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // ----------------------------------------------------------
  // CLOCK IN
  // ----------------------------------------------------------

  static Future<void> punchIn() async {
    await _addPunch("IN");
  }

  // ----------------------------------------------------------
  // CLOCK OUT
  // ----------------------------------------------------------

  static Future<void> punchOut() async {
    await _addPunch("OUT");
  }

  // ----------------------------------------------------------
  // BREAK IN
  // ----------------------------------------------------------

  static Future<void> breakIn() async {
    await _addPunch("BREAK_IN");
  }

  // ----------------------------------------------------------
  // BREAK OUT
  // ----------------------------------------------------------

  static Future<void> breakOut() async {
    await _addPunch("BREAK_OUT");
  }

  static Future<bool> canMarkAttendance() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception("Location service is disabled");
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception("Location permission denied");
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        "Location permission permanently denied. Enable it from Settings.",
      );
    }

    Position position = await Geolocator.getCurrentPosition(
      //desiredAccuracy: LocationAccuracy.high,
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    print("====================================");
    print("CURRENT LAT      = ${position.latitude}");
    print("CURRENT LNG      = ${position.longitude}");
    print("ACCURACY         = ${position.accuracy} meters");
    print("OFFICE LAT       = $officeLat");
    print("OFFICE LNG       = $officeLng");
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      officeLat,
      officeLng,
    );

    print("Distance = $distance");
    print("DISTANCE         = $distance meters");
    print("ALLOWED RADIUS   = $allowedRadius meters");
    print("INSIDE OFFICE    = ${distance <= allowedRadius}");
    print("====================================");
    return distance <= allowedRadius;
  }
  // static Future<bool> canMarkAttendance() async {
  //   Position position = await Geolocator.getCurrentPosition(
  //     desiredAccuracy: LocationAccuracy.high,
  //   );

  //   double distance = Geolocator.distanceBetween(
  //     position.latitude,
  //     position.longitude,
  //     officeLat,
  //     officeLng,
  //   );

  //   print("Distance = $distance");

  //   return distance <= allowedRadius;
  // }

  static Future<Map<String, dynamic>?> getTodayAttendance() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    final today = _today();

    final snapshot = await FirebaseFirestore.instance
        .collection("attendance")
        .where("uid", isEqualTo: user.uid)
        .where("date", isEqualTo: today)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return snapshot.docs.first.data();
  } // static Future<void> punchIn() async {
  //   String uid = FirebaseAuth.instance.currentUser!.uid;

  //   String today = DateTime.now().toString().split(' ')[0];

  //   String docId = "${uid}_$today";

  //   DocumentSnapshot userDoc = await FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(uid)
  //       .get();

  //   DocumentReference attendanceRef = FirebaseFirestore.instance
  //       .collection('attendance')
  //       .doc(docId);

  //   DocumentSnapshot attendanceDoc = await attendanceRef.get();

  //   bool isClockedIn = false;

  //   if (attendanceDoc.exists) {
  //     isClockedIn = attendanceDoc['isClockedIn'] ?? false;
  //   }

  //   if (isClockedIn) {
  //     throw Exception("Already Punched In");
  //   }

  //   await attendanceRef.set({
  //     "uid": uid,
  //     "employeeName": userDoc['name'],
  //     "date": today,
  //     "isClockedIn": true,
  //     "totalMinutes": 0,
  //     "workingHours": "0h 0m",
  //   }, SetOptions(merge: true));
  //   SetOptions(merge: true);

  //   await attendanceRef.collection('punches').add({
  //     "type": "IN",
  //     "time": Timestamp.now(),
  //   });
  // }

  // static Future<void> punchOut() async {
  //   String uid = FirebaseAuth.instance.currentUser!.uid;

  //   String today = DateTime.now().toString().split(' ')[0];

  //   String docId = "${uid}_$today";

  //   DocumentReference attendanceRef = FirebaseFirestore.instance
  //       .collection('attendance')
  //       .doc(docId);

  //   DocumentSnapshot attendanceDoc = await attendanceRef.get();

  //   if (!attendanceDoc.exists) {
  //     throw Exception("Please Punch In First");
  //   }

  //   bool isClockedIn = attendanceDoc['isClockedIn'] ?? false;

  //   if (!isClockedIn) {
  //     throw Exception("Already Punched Out");
  //   }

  //   await attendanceRef.collection('punches').add({
  //     "type": "OUT",
  //     "time": Timestamp.now(),
  //   });

  //   await attendanceRef.update({"isClockedIn": false});

  //   await calculateHours(docId);
  // }

  static Future<void> calculateHours(String docId) async {
    QuerySnapshot snap = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(docId)
        .collection('punches')
        .orderBy('time')
        .get();

    int totalMinutes = 0;

    DateTime? inTime;

    for (var doc in snap.docs) {
      String type = doc['type'];

      DateTime time = (doc['time'] as Timestamp).toDate();

      if (type == "IN") {
        inTime = time;
      }

      if (type == "OUT" && inTime != null) {
        totalMinutes += time.difference(inTime).inMinutes;
        inTime = null;
      }
    }

    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(docId)
        .update({
          "totalMinutes": totalMinutes,
          "workingHours": "${totalMinutes ~/ 60}h ${totalMinutes % 60}m",
        });
  }

  static Future<Duration> getTodayWorkingHours() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    String today = DateTime.now().toString().split(' ')[0];

    String docId = "${uid}_$today";

    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(docId)
        .get();

    if (!doc.exists) {
      return Duration.zero;
    }

    int totalMinutes = doc['totalMinutes'] ?? 0;

    return Duration(minutes: totalMinutes);
  }
}
