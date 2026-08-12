// import 'package:emailjs/emailjs.dart' as emailjs;

// class EmailService {
//   static Future<void> sendEmail({
//     required String toEmail,
//     required String title,
//     required String content,
//   }) async {
//     try {
//       print("EMAIL = $toEmail");
//       print("TITLE = $title");
//       print("NAME = $content");
//       final response = await emailjs.send(
//         'service_90wr32y',
//         'template_b04xilb',

//         {'email': toEmail, 'title': title, 'name': content},

//         emailjs.Options(
//           publicKey: '8erlfJzc6WZtfnz0o',
//           privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
//         ),
//       );

//       print("EMAIL SUCCESS = ${response.text}");
//     } catch (e) {
//       print("EMAIL ERROR = $e");
//     }
//   }
// }

import 'package:emailjs/emailjs.dart' as emailjs;

class EmailService {
  static Future<void> sendLeaveApplyEmail({
    required String employeeName,
    required String employeeEmail,
    required String leaveType,
    required DateTime fromDate,
    required DateTime toDate,
    required int days,
    required String reason,
  }) async {
    try {
      await emailjs.send(
        'service_90wr32y',
        'template_b04xilb',

        {
          'employee_name': employeeName,
          'employee_email': employeeEmail,
          'leave_type': leaveType,
          'from_date': fromDate.toString().split(' ')[0],
          'to_date': toDate.toString().split(' ')[0],
          'days': days.toString(),
          'reason': reason,
        },

        emailjs.Options(
          publicKey: '8erlfJzc6WZtfnz0o',
          privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
        ),
      );

      print("EMAIL SUCCESS");
    } catch (e) {
      print("EMAIL ERROR = $e");
    }
  }
}
