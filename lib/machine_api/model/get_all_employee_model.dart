class EmployeeResponse {
  final int count;
  final String? next;
  final String? previous;
  final String msg;
  final int code;
  final List<EmployeeModel> data;

  EmployeeResponse({
    required this.count,
    required this.next,
    required this.previous,
    required this.msg,
    required this.code,
    required this.data,
  });

  factory EmployeeResponse.fromJson(Map<String, dynamic> json) {
    return EmployeeResponse(
      count: (json['count'] as num?)?.toInt() ?? 0,
      next: json['next']?.toString(),
      previous: json['previous']?.toString(),
      msg: json['msg']?.toString() ?? '',
      code: (json['code'] as num?)?.toInt() ?? 0,
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class EmployeeModel {
  final String id;
  final String empCode;
  final String firstName;
  final String lastName;
  final String email;
  final EmployeeDepartment? department;
  final EmployeePosition? position;

  EmployeeModel({
    required this.id,
    required this.empCode,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.department,
    required this.position,
  });

  String get fullName => [
    firstName,
    lastName,
  ].where((part) => part.trim().isNotEmpty).join(' ').trim();

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final dept = json['department'];
    final position = json['position'];
    return EmployeeModel(
      id: json['id']?.toString() ?? '',
      empCode: json['emp_code']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      department: dept is Map<String, dynamic>
          ? EmployeeDepartment.fromJson(dept)
          : null,
      position: position is Map<String, dynamic>
          ? EmployeePosition.fromJson(position)
          : null,
    );
  }
}

class EmployeeDepartment {
  final String deptName;
  EmployeeDepartment({required this.deptName});
  factory EmployeeDepartment.fromJson(Map<String, dynamic> json) =>
      EmployeeDepartment(deptName: json['dept_name']?.toString() ?? '');
}

class EmployeePosition {
  final String positionName;
  EmployeePosition({required this.positionName});
  factory EmployeePosition.fromJson(Map<String, dynamic> json) =>
      EmployeePosition(positionName: json['position_name']?.toString() ?? '');
}
