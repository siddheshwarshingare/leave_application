import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/get_all_employee_model.dart';

class EmployeeService {
  static const String baseUrl =
      'http://192.168.125.104/personnel/api/employees/';

  Future<EmployeeResponse> getEmployees({
    int page = 1,
    required String apiKey,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('API key is missing. Configure EMPLOYEE_API_KEY.');
    }

    final url = Uri.parse(
      baseUrl,
    ).replace(queryParameters: page == 1 ? null : {'page': page.toString()});
    final request = http.Request('GET', url);
    request.headers.addAll({'accept': '*/*', 'authorization': apiKey});

    final response = await request.send().timeout(const Duration(seconds: 30));
    final body = await response.stream.bytesToString();
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Unauthorized. Check your authorization API key.');
    }
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON response object');
    }
    final result = EmployeeResponse.fromJson(decoded);
    if (result.code != 0) {
      throw Exception(result.msg.isEmpty ? 'Employee API failed' : result.msg);
    }
    return result;
  }
}
