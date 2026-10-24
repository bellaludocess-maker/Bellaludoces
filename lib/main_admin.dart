import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/bella_theme.dart';
import 'modules/admin/services/admin_image_picker_service.dart';
import 'modules/admin/views/admin_login_gate.dart';
import 'modules/admin/views/admin_screen.dart';
import 'modules/catalog/controllers/catalog_controller.dart';
import 'modules/catalog/data/catalog_repository.dart';
import 'modules/external/cloudinary/cloudinary_service.dart';
import 'modules/external/config/cloud_config.dart';
import 'modules/external/firebase/firestore_catalog_repository.dart';

/// Entrypoint independente do Aplicativo / Painel Administrativo da Dona.
/// Compilado separadamente da vitrine pública (`www.bellaludoces.com.br`):
/// - Para rodar no navegador/PC: `flutter run -t lib/main_admin.dart`
/// - Para gerar APK Android exclusivo da dona: `flutter build apk -t lib/main_admin.dart`
/// - Para gerar build Web separado: `flutter build web -t lib/main_admin.dart`
void main() {
  runApp(const BellaLuAdminApp());
}

class BellaLuAdminApp extends StatefulWidget {
  final CatalogRepository? catalogRepository;
  final CloudConfig? cloudConfig;
  final CloudinaryService? cloudinaryService;
  final AdminImagePickerService? imagePickerService;
  final bool requirePinLogin;

  const BellaLuAdminApp({
    super.key,
    this.catalogRepository,
    this.cloudConfig,
    this.cloudinaryService,
    this.imagePickerService,
    this.requirePinLogin = true,
  });

  @override
  State<BellaLuAdminApp> createState() => _BellaLuAdminAppState();
}

class _BellaLuAdminAppState extends State<BellaLuAdminApp>
    with WidgetsBindingObserver {
  late final CloudConfig _cloudConfig;
  late final CloudinaryService _cloudinaryService;
  late final AdminImagePickerService _imagePickerService;
  late final CatalogController _catalogController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cloudConfig = widget.cloudConfig ?? CloudConfig();
    _cloudinaryService = widget.cloudinaryService ??
        CloudinaryService(config: _cloudConfig);
    _imagePickerService =
        widget.imagePickerService ?? AdminImagePickerService();
    _catalogController = CatalogController(
      repository: widget.catalogRepository ??
          FirestoreCatalogRepository(config: _cloudConfig),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _catalogController.loadCatalog();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _catalogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminScreen = AdminScreen(
      catalogController: _catalogController,
      cloudinaryService: _cloudinaryService,
      cloudConfig: _cloudConfig,
      imagePickerService: _imagePickerService,
    );

    return ListenableBuilder(
      listenable: _catalogController,
      builder: (context, _) {
        return MaterialApp(
          title: '${AppConstants.storeName} - Painel Gestor',
          debugShowCheckedModeBanner: false,
          theme: BellaTheme.lightTheme,
          home: widget.requirePinLogin
              ? AdminLoginGate(
                  requiredPin: _catalogController.adminPin,
                  authenticatedChild: adminScreen,
                )
              : adminScreen,
        );
      },
    );
  }
}
