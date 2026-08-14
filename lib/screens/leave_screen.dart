import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emailjs/emailjs.dart' as emailjs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:leave_application/services/email_service.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final formKey = GlobalKey<FormState>();
  double totalDays = 0;

  String? selectedLeaveType;
  String? halfDaySession;
  DateTime? fromDate;
  DateTime? toDate;
  bool loading = false;
  final reasonController = TextEditingController();
  String leaveDuration = "Full Day";
  bool emergency = false;
  bool includeHalfDay = false;
  bool isWeeklyOff(DateTime date, List weeklyOff) {
    String dayName = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ][date.weekday - 1];

    return weeklyOff.contains(dayName);
  }

  List<String> leaveTypes = ["Casual Leave", "Sick Leave", "Paid Leave", "LWP"];

  Future pickFromDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        fromDate = picked;
      });
    }
  }

  Future<bool> hasDuplicateLeave(String uid, DateTime from, DateTime to) async {
    QuerySnapshot snap = await FirebaseFirestore.instance
        .collection('leave_requests')
        .where('uid', isEqualTo: uid)
        .get();

    for (var doc in snap.docs) {
      DateTime existingFrom = (doc['fromDate'] as Timestamp).toDate();

      DateTime existingTo = (doc['toDate'] as Timestamp).toDate();

      bool overlap = !(to.isBefore(existingFrom) || from.isAfter(existingTo));

      if (overlap) {
        return true;
      }
    }

    return false;
  }

  int calculateWorkingDays(DateTime from, DateTime to, List weeklyOff) {
    int count = 0;

    for (
      DateTime d = from;
      !d.isAfter(to);
      d = d.add(const Duration(days: 1))
    ) {
      if (!isWeeklyOff(d, weeklyOff)) {
        count++;
      }
    }

    return count;
  }

  Future pickToDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      firstDate: fromDate ?? DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: fromDate ?? DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        toDate = picked;
      });
    }
  }

  submitLeave() async {
    /// FETCH LEAVE APPROVER EMAILS FROM FIREBASE
    DocumentSnapshot approverDoc = await FirebaseFirestore.instance
        .collection('email_recipients')
        .doc('leave_approvers')
        .get();

    if (!approverDoc.exists) {
      throw Exception("Leave approver configuration not found");
    }

    if (approverDoc['active'] != true) {
      throw Exception("Leave email notifications are disabled");
    }

    List<String> notifyEmails = [];

    final primaryEmail = approverDoc['primaryEmail']?.toString().trim();
    final secondaryEmail = approverDoc['secondaryEmail']?.toString().trim();

    if (primaryEmail != null && primaryEmail.isNotEmpty) {
      notifyEmails.add(primaryEmail);
    }

    if (secondaryEmail != null && secondaryEmail.isNotEmpty) {
      notifyEmails.add(secondaryEmail);
    }

    print("Leave notification emails: $notifyEmails");

    String uid = FirebaseAuth.instance.currentUser!.uid;

    if (!formKey.currentState!.validate()) return;

    if (fromDate == null || toDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select dates")));
      return;
    }

    try {
      setState(() {
        loading = true;
      });

      /// Duplicate leave check
      bool duplicate = await hasDuplicateLeave(uid, fromDate!, toDate!);

      if (duplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Leave already applied for these dates"),
          ),
        );
        return;
      }

      /// FETCH USER DATA FIRST
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      /// GET WEEKLY OFF FROM FIREBASE
      List weeklyOff = userDoc['weeklyOff'] ?? [];

      print("USER WEEKLY OFF = $weeklyOff");

      /// CHECK SELECTED DATE CONTAINS WEEKLY OFF
      bool selectedContainsWeeklyOff = false;

      for (
        DateTime d = fromDate!;
        !d.isAfter(toDate!);
        d = d.add(const Duration(days: 1))
      ) {
        if (isWeeklyOff(d, weeklyOff)) {
          selectedContainsWeeklyOff = true;
          break;
        }
      }

      if (selectedContainsWeeklyOff) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "This is your weekly off. Please select another date.",
            ),
          ),
        );
        return;
      }

      /// CALCULATE WORKING DAYS
      int requestedDays = calculateWorkingDays(fromDate!, toDate!, weeklyOff);

      if (requestedDays <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Selected dates are weekly off / holidays"),
          ),
        );
        return;
      }

      /// LEAVE BALANCE CHECK
      DocumentSnapshot balanceDoc = await FirebaseFirestore.instance
          .collection('toatl_leave')
          .doc(uid)
          .get();

      if (!balanceDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Leave balance not found")),
        );
        return;
      }

      int cl = int.parse(balanceDoc['Cl'].toString());
      int sl = int.parse(balanceDoc['Sl'].toString());

      if (selectedLeaveType == "Casual Leave" && requestedDays > cl) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Only $cl CL remaining")));
        return;
      }

      if (selectedLeaveType == "Sick Leave" && requestedDays > sl) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Only $sl SL remaining")));
        return;
      }

      /// SAVE LEAVE REQUEST
      await FirebaseFirestore.instance.collection('leave_requests').add({
        "uid": uid,
        "employeeName": userDoc['name'],
        "employeeEmail": userDoc['email'],
        "leaveType": selectedLeaveType,
        "leaveDuration": leaveDuration,
        "days": requestedDays,
        "fromDate": Timestamp.fromDate(fromDate!),
        "toDate": Timestamp.fromDate(toDate!),
        "reason": reasonController.text.trim(),
        "emergency": emergency,
        "status": "Pending",
        "createdAt": Timestamp.now(),
      });
      // for (String receiverEmail in notifyEmails) {
      //   await EmailService.sendEmail(
      //     toEmail: receiverEmail,
      //     title: "New Leave Request Applied",
      //     content:
      //         "${userDoc['name']} applied for $selectedLeaveType leave.\n"
      //         "From: ${fromDate.toString().split(' ')[0]}\n"
      //         "To: ${toDate.toString().split(' ')[0]}\n"
      //         "Reason: ${reasonController.text}",
      //   );
      // }
      /// SEND EMAIL TO ALL LEAVE APPROVERS
      for (final receiverEmail in notifyEmails) {
        try {
          await emailjs.send(
            'service_90wr32y',
            'template_mga5feh',
            {
              'to_email': receiverEmail,

              'employee_name': userDoc['name'],
              'employee_email': userDoc['email'],
              'leave_type': selectedLeaveType,
              'from_date': fromDate.toString().split(' ')[0],
              'to_date': toDate.toString().split(' ')[0],
              'days': requestedDays.toString(),
              'reason': reasonController.text.trim(),
            },
            emailjs.Options(
              publicKey: '8erlfJzc6WZtfnz0o',
              privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
            ),
          );

          print("Leave email sent to: $receiverEmail");
        } catch (emailError) {
          print("Failed to send leave email to $receiverEmail: $emailError");
        }
      }
      /**
       * QuerySnapshot adminSnap =
    await FirebaseFirestore.instance
        .collection('admin_emails')
        .get();

for (var doc in adminSnap.docs) {
  String adminEmail = doc['email'];

  await EmailService.sendEmail(
    email: adminEmail,
    subject: "New Leave Request",
    message:
        "${userDoc['name']} applied for $selectedLeaveType leave.\n"
        "Employee Email: ${userDoc['email']}\n"
        "Days: $requestedDays\n"
        "Reason: ${reasonController.text}",
  );
}
       */

      /// ADMIN NOTIFICATION
      await FirebaseFirestore.instance.collection('notifications').add({
        "role": "admin",
        "uid": null,
        "title": "New Leave Request",
        "body": "${userDoc['name']} applied for $selectedLeaveType leave",
        "isRead": false,
        "createdAt": Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Leave Applied Successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Apply Leave",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        backgroundColor: Colors.blue,
        //  foregroundColor: Colors.black,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Form(
          key: formKey,

          child: ListView(
            children: [
              /// Leave Type
              DropdownButtonFormField(
                decoration: const InputDecoration(
                  labelText: "Leave Type",
                  border: OutlineInputBorder(),
                ),

                value: selectedLeaveType,

                items: leaveTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),

                onChanged: (value) {
                  setState(() {
                    selectedLeaveType = value;
                  });
                },

                validator: (value) {
                  if (value == null) {
                    return "Select Leave Type";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              /// Leave Duration
              DropdownButtonFormField<String>(
                value: leaveDuration,

                decoration: const InputDecoration(
                  labelText: "Leave Duration",
                  border: OutlineInputBorder(),
                ),

                items: const [
                  DropdownMenuItem(value: "Full Day", child: Text("Full Day")),

                  DropdownMenuItem(
                    value: "Half Day Only",
                    child: Text("Half Day Only"),
                  ),

                  // DropdownMenuItem(
                  //   value: "Full + Half Day",
                  //   child: Text("Full + Half Day (1.5 / 2.5 / 3.5)"),
                  // ),
                ],

                onChanged: (value) {
                  setState(() {
                    leaveDuration = value!;

                    if (leaveDuration == "Full Day") {
                      halfDaySession = null;
                    }
                  });
                },
              ),

              const SizedBox(height: 20),

              /// Half Day Session
              if (leaveDuration != "Full Day")
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: halfDaySession,

                      decoration: const InputDecoration(
                        labelText: "Half Day Session",
                        border: OutlineInputBorder(),
                      ),

                      items: const [
                        DropdownMenuItem(
                          value: "First Half",
                          child: Text("First Half"),
                        ),

                        DropdownMenuItem(
                          value: "Second Half",
                          child: Text("Second Half"),
                        ),
                      ],

                      onChanged: (value) {
                        setState(() {
                          halfDaySession = value;
                        });
                      },

                      validator: (value) {
                        if (leaveDuration != "Full Day" && value == null) {
                          return "Select Session";
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),
                  ],
                ),

              /// Reason
              TextFormField(
                controller: reasonController,

                maxLines: 4,

                decoration: const InputDecoration(
                  labelText: "Reason",
                  border: OutlineInputBorder(),
                ),

                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Enter reason";
                  }

                  if (value.length < 10) {
                    return "Reason too short";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              /// From Date
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),

                  side: const BorderSide(),
                ),

                title: Text(
                  fromDate == null
                      ? "Select From Date"
                      : fromDate.toString().split(' ')[0],
                ),

                trailing: const Icon(Icons.calendar_month),

                onTap: pickFromDate,
              ),

              const SizedBox(height: 15),

              /// To Date
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),

                  side: const BorderSide(),
                ),

                title: Text(
                  toDate == null
                      ? "Select To Date"
                      : toDate.toString().split(' ')[0],
                ),

                trailing: const Icon(Icons.calendar_month),

                onTap: pickToDate,
              ),

              const SizedBox(height: 20),

              /// Emergency Toggle
              SwitchListTile(
                title: const Text("Emergency Leave"),

                value: emergency,

                onChanged: (value) {
                  setState(() {
                    emergency = value;
                  });
                },
              ),

              const SizedBox(height: 30),

              /// Submit Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),

                child: ElevatedButton(
                  onPressed: loading ? null : submitLeave,

                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(loading ? 55 : double.infinity, 55),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(loading ? 30 : 10),
                    ),
                  ),

                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),

                    child: loading
                        ? const SizedBox(
                            key: ValueKey("loading"),
                            height: 25,
                            width: 25,

                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text("Submit Leave", key: ValueKey("text")),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
