import '../../../core/constants/app_constants.dart';

/// Configuração central de credenciais de nuvem (Firebase Firestore & Cloudinary).
/// Pode ser definida via `--dart-define` no build ou atualizada em tempo de execução no Admin.
class CloudConfig {
  String firebaseProjectId;
  String firebaseApiKey;
  String cloudinaryCloudName;
  String cloudinaryUploadPreset;

  CloudConfig({
    this.firebaseProjectId = const String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: AppConstants.firebaseProjectId,
    ),
    this.firebaseApiKey = const String.fromEnvironment(
      'FIREBASE_API_KEY',
      defaultValue: '',
    ),
    this.cloudinaryCloudName = const String.fromEnvironment(
      'CLOUDINARY_CLOUD_NAME',
      defaultValue: AppConstants.cloudinaryCloudName,
    ),
    this.cloudinaryUploadPreset = const String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
      defaultValue: AppConstants.cloudinaryUploadPreset,
    ),
  });

  /// Indica se um projeto Firebase real foi configurado.
  bool get isFirebaseConfigured => firebaseProjectId.trim().isNotEmpty;

  /// Indica se o Cloudinary está pronto para upload real.
  bool get isCloudinaryConfigured =>
      cloudinaryCloudName.trim().isNotEmpty &&
      cloudinaryUploadPreset.trim().isNotEmpty;
}
