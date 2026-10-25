/// Constantes globais de negócio e configuração da Bella Lu Doces.
/// Centralizadas no Módulo 0 para que nenhum módulo posterior precise
/// hardcodar informações da loja.
class AppConstants {
  AppConstants._();

  // Identidade da Loja
  static const String storeName = 'Bella Lu Doces';
  static const String logoAssetPath = 'assets/images/logo_bella_lu.jpg';
  static const String storeTagline = 'Doces que tornam o seu dia mais especial!';
  static const String storePromoHighlight = 'Pronta Entrega Hoje!';
  static const String storeQualityMoto =
      'Sabor e qualidade em cada pedacinho!';
  static const String storeIdeaQuote = 'Doce é sempre uma boa ideia!';

  // Canais de Atendimento e Redes Sociais
  static const String whatsappDisplay = '(34) 99116-8044';
  static const String whatsappNumberClean = '5534991168044';
  static const String instagramHandle = '@Bellalu.doces';
  static const String instagramUrl = 'https://www.instagram.com/bellalu.doces/';

  // Regras de Entrega, Retirada e Pagamento
  static const double defaultDeliveryFee = 10.00;
  static const double pickupFee = 0.00;
  static const bool defaultPickupEnabled = false;
  static const String defaultPickupAddress = '';
  static const String defaultPixKey = '34987193964';
  static const String defaultPixHolderName = 'Lucineide da Silva';
  static const String defaultPixBankName = 'Nubank';
  static const String defaultAdminPin = '2026';

  // Configurações de Nuvem (Firebase Firestore & Cloudinary oficial da Bella Lu Doces)
  static const String firebaseProjectId = 'bellaludoces';
  static const String firestoreProductsCollection = 'products';
  static const String firestoreCategoriesCollection = 'categories';
  static const String firestoreSettingsCollection = 'store_settings';
  static const String firestoreOrdersCollection = 'orders';
  static const String firestoreCouponsCollection = 'coupons';
  static const String firestorePixConfigDoc = 'pix_config';
  static const String firestoreAdminSecurityDoc = 'admin_security';
  static const String firestoreDeliveryConfigDoc = 'delivery_config';
  static const String firestoreAdminVersionDoc = 'admin_app_version';

  // Sincronização em Nuvem e Atualizador Automático via GitHub Releases (bellalu-apk)
  static const int currentAdminBuildNumber = 6;
  static const String currentAdminVersionLabel = '2.3.1';
  static const String adminPanelLiveUrl =
      'https://www.bellaludoces.com.br/painel/';
  static const String adminApkDownloadUrl =
      'https://github.com/bellaludocess-maker/bellalu-apk/releases/latest/download/BellaLu_Painel_Admin.apk';
  static const String adminGithubReleaseApiUrl =
      'https://api.github.com/repos/bellaludocess-maker/bellalu-apk/releases/latest';

  // Cloudinary oficial da Bella Lu Doces
  static const String cloudinaryCloudName = 'aq9vse7p';
  static const String cloudinaryUploadPreset = 'bella_lu_preset';

  // InfinitePay Checkout Integrado Oficial ($lucineide-silva-jan) + Cloudflare Worker
  static const String infinitePayHandle = 'lucineide-silva-jan';
  static const String infinitePayRedirectUrl =
      'https://www.bellaludoces.com.br/';
  static const String infinitePayWorkerUrl =
      'https://bellalu-infinitepay.bellaludocess.workers.dev';

  // Identidade da Desenvolvedora (Sunflower Development)
  static const String developerName = 'Sunflower Development';
  static const String developerTagline =
      'Soluções em Sites, Cardápios Digitais e Aplicativos';
  static const String developerLogoAssetPath =
      'assets/images/sunflower_logo.png';
  static const List<Map<String, String>> developerWhatsAppContacts = [
    {
      'display': '(34) 99990-8727',
      'clean': '5534999908727',
    },
    {
      'display': '(34) 99938-7854',
      'clean': '5534999387854',
    },
    {
      'display': '(34) 99684-6299',
      'clean': '5534996846299',
    },
  ];
}
