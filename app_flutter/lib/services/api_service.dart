import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import '../core/app_config.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        print("[API ERROR] ${e.response?.statusCode} - ${e.message}");
        return handler.next(e);
      },
    ));
  }

  // O token agora é opcional [String? token] para não quebrar os ecrãs antigos!
  Future<Map<String, dynamic>> getDashboard(String mes, double meta, [String? token]) async {
    final response = await _dio.get('/dashboard', queryParameters: {
      'mes': mes,
      'meta_mensal': meta,
    });
    return response.data['data'];
  }

  Future<List<dynamic>> getFeed(String mes, [String? token]) async {
    final response = await _dio.get('/feed', queryParameters: {'mes': mes});
    return response.data['data'] ?? [];
  }

  Future<List<dynamic>> getFluxo(String mes, [String? token]) async {
    final response = await _dio.get('/fluxo', queryParameters: {'mes': mes});
    return response.data['data'] ?? [];
  }

  Future<bool> uploadFile(List<int> bytes, String fileName, [String? token]) async {
    FormData formData = FormData.fromMap({
      "file": MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final response = await _dio.post('/upload', data: formData);
    return response.statusCode == 200;
  }
}