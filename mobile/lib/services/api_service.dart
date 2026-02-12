import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';
import 'storage_service.dart';

/// Base API Service for making HTTP requests
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final StorageService _storage = StorageService();

  /// Get authorization headers with JWT token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Make a GET request
  Future<ApiResponse> get(String url, {Map<String, String>? queryParams}) async {
    try {
      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      final headers = await _getHeaders();
      
      final response = await http
          .get(uri, headers: headers)
          .timeout(ApiConfig.timeout);
      
      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('No internet connection');
    } on HttpException {
      return ApiResponse.error('Server error occurred');
    } catch (e) {
      return ApiResponse.error('Request failed: $e');
    }
  }

  /// Make a POST request with retry logic for cold starts
  Future<ApiResponse> post(String url, {Map<String, dynamic>? body}) async {
    int retries = 0;
    
    while (retries <= ApiConfig.maxRetries) {
      try {
        final uri = Uri.parse(url);
        final headers = await _getHeaders();
        
        final response = await http
            .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
            .timeout(ApiConfig.timeout);
        
        return _handleResponse(response);
      } on SocketException {
        if (retries >= ApiConfig.maxRetries) {
          return ApiResponse.error('No internet connection. Please check your network.');
        }
      } on TimeoutException {
        if (retries >= ApiConfig.maxRetries) {
          return ApiResponse.error('Server is starting up. Please try again in a moment.');
        }
      } on HttpException {
        if (retries >= ApiConfig.maxRetries) {
          return ApiResponse.error('Server error occurred');
        }
      } catch (e) {
        if (retries >= ApiConfig.maxRetries) {
          return ApiResponse.error('Request failed: $e');
        }
      }
      
      retries++;
      await Future.delayed(ApiConfig.retryDelay);
    }
    
    return ApiResponse.error('Request failed after retries');
  }

  /// Make a PUT request
  Future<ApiResponse> put(String url, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse(url);
      final headers = await _getHeaders();
      
      final response = await http
          .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(ApiConfig.timeout);
      
      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('No internet connection');
    } on HttpException {
      return ApiResponse.error('Server error occurred');
    } catch (e) {
      return ApiResponse.error('Request failed: $e');
    }
  }

  /// Make a DELETE request
  Future<ApiResponse> delete(String url) async {
    try {
      final uri = Uri.parse(url);
      final headers = await _getHeaders();
      
      final response = await http
          .delete(uri, headers: headers)
          .timeout(ApiConfig.timeout);
      
      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('No internet connection');
    } on HttpException {
      return ApiResponse.error('Server error occurred');
    } catch (e) {
      return ApiResponse.error('Request failed: $e');
    }
  }

  /// Upload a file via multipart/form-data POST request
  Future<ApiResponse> uploadMultipart(
    String url, {
    required Uint8List fileBytes,
    required String filename,
    required String fieldName,
    String? mimeType,
  }) async {
    try {
      final uri = Uri.parse(url);
      final token = await _storage.getToken();

      final request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      MediaType? contentType;
      if (mimeType != null) {
        final parts = mimeType.split('/');
        if (parts.length == 2) {
          contentType = MediaType(parts[0], parts[1]);
        }
      }

      request.files.add(http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: filename,
        contentType: contentType,
      ));

      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('No internet connection');
    } on HttpException {
      return ApiResponse.error('Server error occurred');
    } catch (e) {
      return ApiResponse.error('Upload failed: $e');
    }
  }

  /// Handle HTTP response
  ApiResponse _handleResponse(http.Response response) {
    dynamic body;
    try {
      body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    } catch (_) {
      body = {'error': response.body};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponse.success(body);
    }

    // Try to extract meaningful error message from API body
    String errorMsg = 'Request failed';
    String? errorCode;
    try {
      if (body is Map) {
        if (body.containsKey('code')) {
          errorCode = body['code']?.toString();
        }
        if (body.containsKey('error') && body['error'] != null) {
          errorMsg = body['error'].toString();
        } else if (body.containsKey('message') && body['message'] != null) {
          errorMsg = body['message'].toString();
        } else {
          errorMsg = jsonEncode(body);
        }
      } else if (body is String && body.isNotEmpty) {
        errorMsg = body;
      }
    } catch (_) {
      // fallback to generic
    }

    if (response.statusCode == 401) {
      _storage.clearToken();
      return ApiResponse.error(errorMsg.isNotEmpty ? errorMsg : 'Unauthorized', statusCode: 401, errorCode: errorCode);
    }

    if (response.statusCode == 404) {
      return ApiResponse.error(errorMsg.isNotEmpty ? errorMsg : 'Not found', statusCode: 404, errorCode: errorCode);
    }

    return ApiResponse.error(errorMsg, statusCode: response.statusCode, errorCode: errorCode);
  }

  /// Check API health
  Future<bool> checkHealth() async {
    try {
      final response = await get(ApiConfig.health);
      return response.isSuccess && response.data['status'] == 'healthy';
    } catch (e) {
      return false;
    }
  }
}

/// API Response wrapper
class ApiResponse {
  final bool isSuccess;
  final dynamic data;
  final String? error;
  final int? statusCode;
  final String? errorCode;

  ApiResponse._({
    required this.isSuccess,
    this.data,
    this.error,
    this.statusCode,
    this.errorCode,
  });

  factory ApiResponse.success(dynamic data) {
    return ApiResponse._(isSuccess: true, data: data);
  }

  factory ApiResponse.error(String error, {int? statusCode, String? errorCode}) {
    return ApiResponse._(isSuccess: false, error: error, statusCode: statusCode, errorCode: errorCode);
  }
}
