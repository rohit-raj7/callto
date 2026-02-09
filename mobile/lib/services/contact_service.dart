import 'api_config.dart';
import 'api_service.dart';

class ContactResult {
  final bool success;
  final String? error;

  ContactResult({required this.success, this.error});
}

class ContactService {
  final ApiService _api = ApiService();

  Future<ContactResult> submitContact({
    required String name,
    required String email,
    required String message,
    required String source,
  }) async {
    final response = await _api.post(
      ApiConfig.contactMessages,
      body: {
        'name': name,
        'email': email,
        'message': message,
        'source': source,
      },
    );

    if (response.isSuccess) {
      return ContactResult(success: true);
    }

    return ContactResult(success: false, error: response.error);
  }
}
