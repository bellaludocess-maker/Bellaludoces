import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Resultado da seleção de foto de um doce no celular ou computador.
class PickedProductImage {
  final Uint8List bytes;
  final String fileName;

  const PickedProductImage({
    required this.bytes,
    required this.fileName,
  });
}

typedef CustomImagePickerCallback = Future<PickedProductImage?> Function();

/// Serviço de captura de foto (Galeria / Explorador de Arquivos do PC)
/// integrado com o `CloudinaryService`.
class AdminImagePickerService {
  final CustomImagePickerCallback? customPicker;
  final ImagePicker _picker = ImagePicker();

  AdminImagePickerService({this.customPicker});

  Future<PickedProductImage?> pickFromGallery() async {
    if (customPicker != null) {
      return customPicker!();
    }

    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );

    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedProductImage(
      bytes: bytes,
      fileName: file.name.isNotEmpty ? file.name : 'doce_bella_lu.jpg',
    );
  }
}
