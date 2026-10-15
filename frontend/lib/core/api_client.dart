import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const String baseUrl = 'http://localhost:5083/api';
  static const _storage = FlutterSecureStorage();

  // Singleton Dio instance — interceptor is added only once.
  static final Dio dio = _buildDio();

  static Dio _buildDio() {
    final d = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        return handler.next(e);
      },
    ));

    return d;
  }

  static Future<void> saveToken(String token) =>
      _storage.write(key: 'jwt_token', value: token);

  static Future<String?> getToken() => _storage.read(key: 'jwt_token');

  static Future<void> clearToken() => _storage.delete(key: 'jwt_token');

  /// Broadcasts a class schedule notification to all students.
  static Future<String> broadcastClassTime({
    int? courseId,
    required String classTime,
    required String topic,
  }) async {
    final res = await dio.post('/notifications/broadcast-class-time', data: {
      if (courseId != null) 'courseId': courseId,
      'classTime': classTime,
      'topic': topic,
    });
    final data = res.data as Map<String, dynamic>;
    return data['message'] as String? ?? 'Broadcast sent!';
  }
}
