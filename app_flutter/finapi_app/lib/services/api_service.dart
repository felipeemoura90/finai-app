import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://172.16.2.168:8000/api';

  // Função auxiliar para criar os cabeçalhos com o token
  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // <-- O "crachá" para o servidor
    };
  }

  Future<Map<String, dynamic>> getDashboard(
    String mes,
    double meta,
    String token,
  ) async {
    final url = Uri.parse('$_baseUrl/dashboard?mes=$mes&meta_mensal=$meta');
    final response = await http.get(url, headers: _getHeaders(token));

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Erro ao carregar Dashboard: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getFeed(String mes, String token) async {
    final url = Uri.parse('$_baseUrl/feed?mes=$mes');
    final response = await http.get(url, headers: _getHeaders(token));

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? [];
    } else {
      throw Exception('Erro ao carregar Feed: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getFluxo(String mes, String token) async {
    final url = Uri.parse('$_baseUrl/fluxo?mes=$mes');
    final response = await http.get(url, headers: _getHeaders(token));

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? [];
    } else {
      throw Exception('Erro ao carregar Fluxo: ${response.statusCode}');
    }
  }

  Future<bool> uploadFile(
    List<int> bytes,
    String fileName,
    String token,
  ) async {
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/upload'));
    request.headers.addAll({'Authorization': 'Bearer $token'});
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    var response = await request.send();
    return response.statusCode == 200;
  }
}
