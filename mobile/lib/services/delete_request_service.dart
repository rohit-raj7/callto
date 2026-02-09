import 'api_config.dart';
import 'api_service.dart';

class DeleteRequestResult {
  final bool success;
  final String? message;
  final String? error;

  DeleteRequestResult({required this.success, this.message, this.error});
}

class DeleteRequestService {
  final ApiService _api = ApiService();

  // Submit delete account request to backend API
  Future<DeleteRequestResult> submitDeleteRequest({
    required String name,
    required String email,
    required String phone,
    required String reason,
    required String role,
    required String userId,
  }) async {
    final response = await _api.post(
      ApiConfig.deleteAccountRequest,
      body: {
        'name': name,
        'email': email,
        'phone': phone,
        'reason': reason,
        'role': role,
        'userId': userId,
      },
    );

    if (response.isSuccess) {
      return DeleteRequestResult(
        success: true,
        message: response.data['message']?.toString(),
      );
    }

    return DeleteRequestResult(
      success: false,
      error: response.error ?? 'Failed to submit delete request',
    );
  }
}
