import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../state/multiplayer/server_url_provider.dart';

/// Sunucudaki `/api/*` uclarina yapilan cagrilarda firlatilan hata; mesaji
/// dogrudan kullaniciya gosterilebilecek sekilde Turkce ve kisa tutulur.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Cok oyunculu sunucudaki (aynı adres, Socket.IO ile paylasilan) kimlik
/// dogrulamali REST uclarina (magaza satin alma, seviye odulu toplama,
/// çark cevirme, atolye vb.) istek atmak icin ince bir sarmalayici.
/// Her istekte guncel Firebase ID token'i alip `Authorization: Bearer`
/// basligina ekler - sunucu tarafinda ayni token server/server.js'deki
/// requireAuth middleware'iyle dogrulanir.
class ApiClient {
  const ApiClient(this._baseUrl);

  final String _baseUrl;

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final token = await fb_auth.FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw const ApiException('Oturum bulunamadı, lütfen tekrar giriş yapın.');

    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body ?? const <String, dynamic>{}),
      );
    } catch (e) {
      throw ApiException('Sunucuya ulaşılamadı: $e');
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw ApiException(decoded['error'] as String? ?? 'Bilinmeyen bir hata oluştu.');
    }
    return decoded;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(serverUrlProvider));
});
