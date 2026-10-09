import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../model/get_all_employee_model.dart';
import '../service/get_all_employee_service.dart';

class EmployeeController extends GetxController {
  EmployeeController({required this.apiKey});

  final String apiKey;
  final EmployeeService service = EmployeeService();

  final RxBool isLoading = false.obs;
  final RxBool isLoadMore = false.obs;
  final Rxn<EmployeeResponse> employeeList = Rxn<EmployeeResponse>();
  final RxString errorMessage = ''.obs;
  final RxInt totalCount = 0.obs;
  final RxInt currentPage = 1.obs;

  String? nextPageUrl;
  bool get hasMore => nextPageUrl != null && nextPageUrl!.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    fetchEmployees();
  }

  Future<void> fetchEmployees() async {
    if (isLoading.value || isLoadMore.value) return;
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final response = await service.getEmployees(page: 1, apiKey: apiKey);
      employeeList.value = response;
      totalCount.value = response.count;
      currentPage.value = 1;
      nextPageUrl = response.next;
      debugPrint('Employees loaded: ${response.data.length}');
    } catch (e) {
      errorMessage.value = e.toString();
      debugPrint('Employee API error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMoreEmployees() async {
    if (isLoading.value || isLoadMore.value || !hasMore) return;
    try {
      isLoadMore.value = true;
      errorMessage.value = '';
      final nextPage = currentPage.value + 1;
      final response = await service.getEmployees(
        page: nextPage,
        apiKey: apiKey,
      );
      final existing = employeeList.value;
      if (existing == null) {
        employeeList.value = response;
      } else {
        existing.data.addAll(response.data);
        employeeList.refresh();
      }
      totalCount.value = response.count;
      currentPage.value = nextPage;
      nextPageUrl = response.next;
    } catch (e) {
      errorMessage.value = e.toString();
      debugPrint('Load more employees error: $e');
    } finally {
      isLoadMore.value = false;
    }
  }

  Future<void> refreshEmployees() => fetchEmployees();

  EmployeeModel? getEmployeeByCode(String code) {
    final items = employeeList.value?.data ?? <EmployeeModel>[];
    for (final employee in items) {
      if (employee.empCode == code) return employee;
    }
    return null;
  }
}
