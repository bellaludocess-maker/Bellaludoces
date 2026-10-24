import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/cloud_config.dart';

/// Serviço de integração com o Cloudinary (Módulo 4).
/// Realiza upload direto via Unsigned Preset (sem necessidade de backend próprio)
/// e aplica otimização automática (`f_auto,q_auto`) nas URLs das fotos dos doces.
class CloudinaryService {
  final CloudConfig config;
  final http.Client _httpClient;

  CloudinaryService({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Endpoint oficial da API de upload de imagens do Cloudinary.
  Uri get uploadEndpoint => Uri.parse(
        'https://api.cloudinary.com/v1_1/${config.cloudinaryCloudName}/image/upload',
      );

  /// Injeta parâmetros de CDN (`f_auto,q_auto,c_fill`) em URLs do Cloudinary
  /// para carregamento instantâneo em 4G e navegadores Web/Mobile.
  static String optimizeCloudinaryUrl(
    String url, {
    int width = 700,
    int height = 500,
  }) {
    if (!url.contains('res.cloudinary.com') || !url.contains('/image/upload/')) {
      return url;
    }
    if (url.contains('f_auto,q_auto')) {
      return url;
    }
    return url.replaceFirst(
      '/image/upload/',
      '/image/upload/f_auto,q_auto,c_fill,w_$width,h_$height/',
    );
  }

  /// Faz o upload dos bytes de uma imagem diretamente para o Cloudinary.
  /// Caso as credenciais ainda estejam em modo local/demonstração, retorna
  /// um Data URI (`data:image/jpeg;base64,...`) para que a foto funcione imediatamente.
  Future<String> uploadImageBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!config.isCloudinaryConfigured) {
      final base64Image = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64Image';
    }

    try {
      final request = http.MultipartRequest('POST', uploadEndpoint)
        ..fields['upload_preset'] = config.cloudinaryUploadPreset
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
          ),
        );

      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = (body['secure_url'] ?? body['url'] ?? '') as String;
        if (secureUrl.isNotEmpty) {
          return optimizeCloudinaryUrl(secureUrl);
        }
      }
    } catch (_) {
      // Fallback resiliente para Data URI caso esteja sem conexão ou em ambiente de teste
    }

    final base64Image = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64Image';
  }
}
