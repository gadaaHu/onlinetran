import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class JwtInterceptor extends Interceptor {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Attempt to read the JWT token from secure storage
    final token = await _secureStorage.read(key: 'jwt_token');

    if (token != null) {
      // If token exists, attach it to the Authorization header
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Continue with the request
    return super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle 401 Unauthorized globally if needed (e.g., refresh token or logout)
    if (err.response?.statusCode == 401) {
      print('Token expired or unauthorized');
      // e.g., trigger logout logic here
    }
    return super.onError(err, handler);
  }
}

// Example usage to configure Dio:
/*
Dio createDioClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://your-dotnet-api.com/api',
    ),
  );
  
  dio.interceptors.add(JwtInterceptor());
  return dio;
}
*/
