import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/bella_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/bella_badge.dart';
import '../../../core/widgets/sunflower_developer_badge.dart';
import '../../catalog/controllers/catalog_controller.dart';
import '../../catalog/models/category_model.dart';
import '../../catalog/models/coupon_model.dart';
import '../../catalog/models/product_model.dart';
import '../../catalog/models/product_option.dart';
import '../../catalog/views/widgets/product_illustration_banner.dart';
import '../../checkout/models/checkout_order_model.dart';
import '../../external/cloudinary/cloudinary_service.dart';
import '../../external/config/cloud_config.dart';
import '../services/admin_image_picker_service.dart';

/// Painel Administrativo Exclusivo da Loja (Módulo 5).
/// Otimizado tanto para Mobile (APK Android / tela compacta sem sobreposição)
/// quanto para PC, permitindo:
/// 1. Cadastrar novos produtos no catálogo;
/// 2. Editar produtos já publicados em uma janela Pop-up direta (nome, valor, 2º preço, sabores, descrição, foto, categoria) ou Excluir;
/// 3. Criar novas categorias dinamicamente;
/// 4. Ativar ou pausar produtos esgotados em tempo real;
/// 5. Acompanhar pedidos recebidos e configurar Chave Pix, Banco e PIN.
class AdminScreen extends StatefulWidget {
  final CatalogController catalogController;
  final CloudinaryService cloudinaryService;
  final CloudConfig cloudConfig;
  final AdminImagePickerService imagePickerService;

  const AdminScreen({
    super.key,
    required this.catalogController,
    required this.cloudinaryService,
    required this.cloudConfig,
    required this.imagePickerService,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Controllers para Cadastrar Novo Produto
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _secondaryPriceController = TextEditingController();
  final _flavorsController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _newCategoryController = TextEditingController();
  final _dialogCategoryController = TextEditingController();

  // Controllers para a Janela Pop-up de Edição de Produto
  final _editNameController = TextEditingController();
  final _editPriceController = TextEditingController();
  final _editSecondaryPriceController = TextEditingController();
  final _editFlavorsController = TextEditingController();
  final _editDescriptionController = TextEditingController();
  final _editImageUrlController = TextEditingController();

  late final TextEditingController _pixKeyController;
  late final TextEditingController _pixHolderController;
  late final TextEditingController _pixBankController;
  late final TextEditingController _deliveryFeeController;
  late final TextEditingController _pickupAddressController;
  late final TextEditingController _adminPinController;
  bool _isPickupEnabled = AppConstants.defaultPickupEnabled;

  // Controllers para Cupons de Desconto
  final _couponCodeController = TextEditingController();
  final _couponValueController = TextEditingController();
  final _couponMinOrderController = TextEditingController();
  CouponDiscountType _selectedCouponType = CouponDiscountType.percentage;
  bool _couponOncePerCustomer = true;

  // Estado de verificação automática de atualização via GitHub Releases / Nuvem
  bool _hasRemoteCloudUpdate = false;
  bool _updateDialogShown = false;
  String _remoteCloudVersionLabel = '';
  String _remoteApkDirectUrl = AppConstants.adminApkDownloadUrl;

  // Aba de filtro dos Pedidos Recebidos ('pending', 'completed', 'all')
  String _ordersTab = 'pending';

  String _selectedCategoryId = 'pipocas';
  bool _isUploadingPhoto = false;
  bool _isSavingProduct = false;

  @override
  void initState() {
    super.initState();
    _pixKeyController = TextEditingController(
      text: widget.catalogController.pixKey,
    );
    _pixHolderController = TextEditingController(
      text: widget.catalogController.pixHolderName,
    );
    _pixBankController = TextEditingController(
      text: widget.catalogController.pixBankName,
    );
    _deliveryFeeController = TextEditingController(
      text: widget.catalogController.deliveryFee
          .toStringAsFixed(2)
          .replaceAll('.', ','),
    );
    _pickupAddressController = TextEditingController(
      text: widget.catalogController.pickupAddress,
    );
    _isPickupEnabled = widget.catalogController.isPickupEnabled;
    _adminPinController = TextEditingController(
      text: widget.catalogController.adminPin,
    );
    widget.catalogController.addListener(_syncStoreConfigControllers);
    _checkRemoteCloudUpdate();
  }

  void _syncStoreConfigControllers() {
    if (!mounted) return;
    if (_isPickupEnabled != widget.catalogController.isPickupEnabled) {
      setState(() {
        _isPickupEnabled = widget.catalogController.isPickupEnabled;
      });
    }
    if (_pickupAddressController.text.trim().isEmpty &&
        widget.catalogController.pickupAddress.isNotEmpty) {
      _pickupAddressController.text = widget.catalogController.pickupAddress;
    }
  }

  Future<void> _checkRemoteCloudUpdate() async {
    if (kIsWeb || !widget.cloudConfig.isFirebaseConfigured) return;
    int detectedBuild = 0;
    String detectedLabel = '';
    String detectedApkUrl = AppConstants.adminApkDownloadUrl;

    // 1. Verifica GitHub Releases (repositório oficial bellalu-apk)
    try {
      final ghResponse = await http
          .get(
            Uri.parse(AppConstants.adminGithubReleaseApiUrl),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 4));
      if (ghResponse.statusCode == 200) {
        final ghMap = jsonDecode(ghResponse.body);
        if (ghMap is Map<String, dynamic>) {
          final tagName = (ghMap['tag_name'] ?? '').toString().trim();
          final buildMatch = RegExp(r'b(\d+)$|v(\d+)$').firstMatch(tagName);
          final parsedTagBuild = buildMatch != null
              ? int.tryParse(buildMatch.group(1) ?? buildMatch.group(2) ?? '0')
              : int.tryParse(tagName.replaceAll(RegExp(r'[^0-9]'), ''));
          if (parsedTagBuild != null && parsedTagBuild > detectedBuild) {
            detectedBuild = parsedTagBuild;
            detectedLabel = (ghMap['name'] ?? tagName).toString().trim();
          }
          final assets = ghMap['assets'];
          if (assets is List && assets.isNotEmpty) {
            for (final asset in assets) {
              if (asset is Map &&
                  (asset['browser_download_url'] ?? '')
                      .toString()
                      .endsWith('.apk')) {
                detectedApkUrl =
                    asset['browser_download_url'].toString().trim();
                break;
              }
            }
          }
        }
      }
    } catch (_) {}

    // 2. Verifica também o version.json no painel web (/painel/version.json)
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConstants.adminPanelLiveUrl}version.json?t=${DateTime.now().millisecondsSinceEpoch}',
            ),
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final remoteBuild =
              int.tryParse((decoded['buildNumber'] ?? '0').toString()) ?? 0;
          final remoteLabel = (decoded['version'] ?? '').toString().trim();
          final customApkUrl = (decoded['apkUrl'] ?? '').toString().trim();
          if (remoteBuild > detectedBuild) {
            detectedBuild = remoteBuild;
            if (remoteLabel.isNotEmpty) detectedLabel = remoteLabel;
          }
          if (customApkUrl.isNotEmpty) {
            detectedApkUrl = customApkUrl;
          }
        }
      }
    } catch (_) {}

    if (detectedBuild > AppConstants.currentAdminBuildNumber && mounted) {
      setState(() {
        _hasRemoteCloudUpdate = true;
        _remoteCloudVersionLabel =
            detectedLabel.isNotEmpty ? detectedLabel : 'v$detectedBuild';
        _remoteApkDirectUrl = detectedApkUrl;
      });
      if (!_updateDialogShown) {
        _updateDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAutoUpdateDialog();
        });
      }
    }
  }

  Future<void> _showAutoUpdateDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.system_update_rounded,
                color: BellaColors.pinkPrimary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nova Atualização ($_remoteCloudVersionLabel)!',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Uma nova versão do aplicativo Painel Bella Lu Doces está disponível no GitHub. Toque em "Baixar e Atualizar APK" para instalar agora mesmo!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Depois'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _downloadLatestAdminApk();
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Baixar e Atualizar APK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openLiveCloudPanel() async {
    final uri = Uri.parse(AppConstants.adminPanelLiveUrl);
    try {
      final openedInApp = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!openedInApp) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _downloadLatestAdminApk() async {
    final uri = Uri.parse(_remoteApkDirectUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    widget.catalogController.removeListener(_syncStoreConfigControllers);
    _scrollController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _secondaryPriceController.dispose();
    _flavorsController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _newCategoryController.dispose();
    _dialogCategoryController.dispose();
    _editNameController.dispose();
    _editPriceController.dispose();
    _editSecondaryPriceController.dispose();
    _editFlavorsController.dispose();
    _editDescriptionController.dispose();
    _editImageUrlController.dispose();
    _pixKeyController.dispose();
    _pixHolderController.dispose();
    _pixBankController.dispose();
    _deliveryFeeController.dispose();
    _pickupAddressController.dispose();
    _adminPinController.dispose();
    _couponCodeController.dispose();
    _couponValueController.dispose();
    _couponMinOrderController.dispose();
    super.dispose();
  }

  List<CategoryModel> get _selectableCategories {
    final cats = widget.catalogController.categories
        .where((c) => c.id != 'all')
        .toList();
    if (cats.isEmpty) {
      return const [
        CategoryModel(id: 'pipocas', name: 'Pipocas Gourmet', sortOrder: 1),
        CategoryModel(id: 'bolos', name: 'Bolos Caseiros', sortOrder: 2),
      ];
    }
    return cats;
  }

  /// Constrói um `ProductModel` normalizado a partir dos campos de criação ou edição.
  ProductModel _buildProductFromInputs({
    required String? existingId,
    required String name,
    required String rawPriceText,
    required String rawSecondaryPriceText,
    required String categoryId,
    required String rawFlavorsText,
    required String descriptionText,
    required String imageUrlText,
    required bool isAvailable,
    required bool isReadyDelivery,
  }) {
    final cleanPrice = rawPriceText
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();
    final basePrice = double.tryParse(cleanPrice) ?? 20.0;

    final cleanSecondary = rawSecondaryPriceText
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();
    final secondaryPrice =
        cleanSecondary.isNotEmpty ? double.tryParse(cleanSecondary) : null;

    final rawFlavors = rawFlavorsText
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final flavorList = rawFlavors.isEmpty ? ['Tradicional'] : rawFlavors;

    final productOptions = <ProductOption>[];
    for (int i = 0; i < flavorList.length; i++) {
      productOptions.add(
        ProductOption(
          id: 'opt_${DateTime.now().millisecondsSinceEpoch}_$i',
          name: flavorList[i],
          additionalPrice: 0.0,
        ),
      );
    }

    final categories = _selectableCategories;
    final matchedCategory = categories.where((c) => c.id == categoryId);
    final categoryName = matchedCategory.isNotEmpty
        ? matchedCategory.first.name
        : 'Produtos';

    final slugId = existingId != null && existingId.isNotEmpty
        ? existingId
        : name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');

    final productId = slugId.isNotEmpty
        ? slugId
        : 'prod-${DateTime.now().millisecondsSinceEpoch}';

    final optionGroups = <ProductOptionGroup>[];
    if (secondaryPrice != null && secondaryPrice > basePrice) {
      final diff =
          double.parse((secondaryPrice - basePrice).toStringAsFixed(2));
      optionGroups.add(
        ProductOptionGroup(
          id: 'group-tamanho-$productId',
          title: 'Escolha a Opção / Tamanho',
          isRequired: true,
          options: [
            ProductOption(
              id: 'tam-1',
              name:
                  'Pacote Tradicional (${CurrencyFormatter.formatBRL(basePrice)})',
              additionalPrice: 0.0,
            ),
            ProductOption(
              id: 'tam-2',
              name:
                  'Pacote Especial (${CurrencyFormatter.formatBRL(secondaryPrice)})',
              additionalPrice: diff,
            ),
          ],
        ),
      );
    }
    optionGroups.add(
      ProductOptionGroup(
        id: 'group-sabor-$productId',
        title: 'Escolha o Sabor / Opção',
        isRequired: true,
        options: productOptions,
      ),
    );

    return ProductModel(
      id: productId,
      name: name,
      description: descriptionText.trim().isNotEmpty
          ? descriptionText.trim()
          : 'Produto especial feito com carinho pela Bella Lu.',
      imageUrl: imageUrlText.trim().isNotEmpty
          ? imageUrlText.trim()
          : 'assets/novo_produto',
      basePrice: basePrice,
      secondaryPrice: secondaryPrice,
      categoryId: categoryId,
      categoryName: categoryName,
      options: productOptions,
      optionGroups: optionGroups,
      isAvailable: isAvailable,
      isReadyDelivery: isReadyDelivery,
    );
  }

  /// Abre a janela Pop-up de edição imediata do produto selecionado.
  Future<void> _showEditProductDialog(ProductModel product) async {
    _editNameController.text = product.name;
    _editPriceController.text =
        product.basePrice.toStringAsFixed(2).replaceAll('.', ',');
    _editSecondaryPriceController.text = product.secondaryPrice != null
        ? product.secondaryPrice!.toStringAsFixed(2).replaceAll('.', ',')
        : '';
    _editFlavorsController.text = product.flavorNames.join(', ');
    _editDescriptionController.text = product.description;
    _editImageUrlController.text = product.imageUrl;

    final categories = _selectableCategories;
    String dialogCategoryId =
        categories.any((c) => c.id == product.categoryId)
            ? product.categoryId
            : categories.first.id;
    bool isUploadingInDialog = false;

    final updatedProduct = await showDialog<ProductModel>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: BellaColors.pinkPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Editando: ${product.name}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey('edit_dialog_name_input'),
                        controller: _editNameController,
                        style: const TextStyle(fontSize: 13.5),
                        decoration: const InputDecoration(
                          labelText: 'Nome do Produto *',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey('edit_dialog_price_input'),
                              controller: _editPriceController,
                              style: const TextStyle(fontSize: 13.5),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Preço (R\$) *',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              key: const ValueKey(
                                'edit_dialog_secondary_price_input',
                              ),
                              controller: _editSecondaryPriceController,
                              style: const TextStyle(fontSize: 13.5),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: '2º Preço (Opc.)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('edit_dialog_category_dropdown'),
                        isExpanded: true,
                        initialValue: dialogCategoryId,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: BellaColors.darkChocolate,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat.id,
                            child: Text(
                              cat.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => dialogCategoryId = val);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('edit_dialog_flavors_input'),
                        controller: _editFlavorsController,
                        style: const TextStyle(fontSize: 13.5),
                        decoration: const InputDecoration(
                          labelText: 'Sabores / Opções (separados por vírgula)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('edit_dialog_desc_input'),
                        controller: _editDescriptionController,
                        style: const TextStyle(fontSize: 13.5),
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Descrição do Produto',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key:
                                  const ValueKey('edit_dialog_image_url_input'),
                              controller: _editImageUrlController,
                              style: const TextStyle(fontSize: 12.5),
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Foto do Produto',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            key: const ValueKey(
                              'edit_dialog_pick_photo_button',
                            ),
                            onPressed: isUploadingInDialog
                                ? null
                                : () async {
                                    setDialogState(
                                      () => isUploadingInDialog = true,
                                    );
                                    try {
                                      final picked = await widget
                                          .imagePickerService
                                          .pickFromGallery();
                                      if (picked != null) {
                                        final url = await widget
                                            .cloudinaryService
                                            .uploadImageBytes(
                                          bytes: picked.bytes,
                                          fileName: picked.fileName,
                                        );
                                        setDialogState(() {
                                          _editImageUrlController.text = url;
                                        });
                                      }
                                    } finally {
                                      setDialogState(
                                        () => isUploadingInDialog = false,
                                      );
                                    }
                                  },
                            icon: isUploadingInDialog
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 16,
                                  ),
                            label: const Text('Trocar Foto'),
                          ),
                        ],
                      ),
                      if (_editImageUrlController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ProductIllustrationBanner(
                            product: product.copyWith(
                              imageUrl: _editImageUrlController.text.trim(),
                            ),
                            height: 100,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  key: const ValueKey('edit_dialog_save_button'),
                  onPressed: () {
                    final built = _buildProductFromInputs(
                      existingId: product.id,
                      name: _editNameController.text.trim().isNotEmpty
                          ? _editNameController.text.trim()
                          : product.name,
                      rawPriceText: _editPriceController.text,
                      rawSecondaryPriceText: _editSecondaryPriceController.text,
                      categoryId: dialogCategoryId,
                      rawFlavorsText: _editFlavorsController.text,
                      descriptionText: _editDescriptionController.text,
                      imageUrlText: _editImageUrlController.text,
                      isAvailable: product.isAvailable,
                      isReadyDelivery: product.isReadyDelivery,
                    );
                    Navigator.of(dialogContext).pop(built);
                  },
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Salvar Alterações'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updatedProduct != null && mounted) {
      await widget.catalogController.saveProduct(updatedProduct);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: BellaColors.successGreen,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Produto "${updatedProduct.name}" atualizado com sucesso!',
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Abre confirmação para excluir um produto do catálogo.
  Future<void> _confirmDeleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Excluir Produto?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Deseja remover "${product.name}" do cardápio da loja?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              key: const ValueKey('confirm_delete_product_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BellaColors.errorRed,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sim, Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await widget.catalogController.deleteProduct(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: BellaColors.darkChocolate,
          content: Text('Produto "${product.name}" removido do cardápio.'),
        ),
      );
    }
  }

  Future<void> _handleAddNewCategory([String? customName]) async {
    final rawName = (customName ?? _newCategoryController.text).trim();
    if (rawName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BellaColors.errorRed,
          content: Text('Digite o nome da nova categoria.'),
        ),
      );
      return;
    }

    final slugId = rawName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    final categoryId = slugId.isNotEmpty
        ? slugId
        : 'cat-${DateTime.now().millisecondsSinceEpoch}';

    final newCategory = CategoryModel(
      id: categoryId,
      name: rawName,
      sortOrder: widget.catalogController.categories.length + 1,
    );

    await widget.catalogController.saveCategory(newCategory);
    if (!mounted) return;

    setState(() {
      _selectedCategoryId = newCategory.id;
      _newCategoryController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BellaColors.successGreen,
        content: Row(
          children: [
            const Icon(Icons.category_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Nova categoria "${newCategory.name}" criada!'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuickCategoryDialog() async {
    _dialogCategoryController.clear();
    final createdCategoryName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.create_new_folder_rounded,
                color: BellaColors.pinkPrimary,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nova Categoria',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: TextField(
            key: const ValueKey('dialog_new_category_input'),
            controller: _dialogCategoryController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome da Categoria',
              hintText: 'Ex: Kits Presente, Salgados, Bebidas...',
            ),
            onSubmitted: (val) {
              Navigator.of(dialogContext).pop(val);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              key: const ValueKey('dialog_confirm_category_button'),
              onPressed: () {
                Navigator.of(dialogContext).pop(_dialogCategoryController.text);
              },
              child: const Text('Criar Categoria'),
            ),
          ],
        );
      },
    );
    if (createdCategoryName != null && mounted) {
      await _handleAddNewCategory(createdCategoryName);
    }
  }

  Future<void> _handlePickAndUploadPhoto() async {
    setState(() => _isUploadingPhoto = true);
    try {
      final picked = await widget.imagePickerService.pickFromGallery();
      if (picked != null) {
        final uploadedUrl = await widget.cloudinaryService.uploadImageBytes(
          bytes: picked.bytes,
          fileName: picked.fileName,
        );
        if (mounted) {
          setState(() {
            _imageUrlController.text = uploadedUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: BellaColors.successGreen,
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Foto carregada e otimizada com sucesso!'),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BellaColors.errorRed,
            content: Text('Erro ao carregar foto: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _handleSaveNewProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSavingProduct = true);

    final newProduct = _buildProductFromInputs(
      existingId: null,
      name: _nameController.text.trim(),
      rawPriceText: _priceController.text,
      rawSecondaryPriceText: _secondaryPriceController.text,
      categoryId: _selectedCategoryId,
      rawFlavorsText: _flavorsController.text,
      descriptionText: _descriptionController.text,
      imageUrlText: _imageUrlController.text,
      isAvailable: true,
      isReadyDelivery: true,
    );

    await widget.catalogController.saveProduct(newProduct);

    if (!mounted) return;
    setState(() {
      _isSavingProduct = false;
      _nameController.clear();
      _priceController.clear();
      _secondaryPriceController.clear();
      _flavorsController.clear();
      _descriptionController.clear();
      _imageUrlController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BellaColors.darkChocolate,
        content: Row(
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: BellaColors.pinkLight,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('"${newProduct.name}" publicado na vitrine!'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSavePixConfig() async {
    final key = _pixKeyController.text.trim();
    final holder = _pixHolderController.text.trim();
    final bank = _pixBankController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BellaColors.errorRed,
          content: Text('Informe a chave Pix da loja.'),
        ),
      );
      return;
    }

    await widget.catalogController.savePixConfig(
      pixKey: key,
      pixHolderName: holder,
      pixBankName: bank,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BellaColors.successGreen,
        content: Row(
          children: [
            const Icon(Icons.qr_code_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Chave Pix atualizada para "$key" ($holder • Banco: $bank)!',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSaveDeliveryFee() async {
    final clean = _deliveryFeeController.text
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();
    final parsed = double.tryParse(clean);
    if (parsed == null || parsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BellaColors.errorRed,
          content: Text('Informe um valor válido para a taxa de entrega.'),
        ),
      );
      return;
    }

    await widget.catalogController.saveDeliveryFee(parsed);
    if (!mounted) return;

    _deliveryFeeController.text =
        parsed.toStringAsFixed(2).replaceAll('.', ',');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BellaColors.successGreen,
        content: Row(
          children: [
            const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Taxa de entrega atualizada para ${CurrencyFormatter.formatBRL(parsed)}!',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSavePickupConfig({bool? overrideEnabled}) async {
    final enabled = overrideEnabled ?? _isPickupEnabled;
    final address = _pickupAddressController.text.trim();

    if (enabled && address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BellaColors.errorRed,
          content: Text(
            'Informe o endereço físico do local para ativar a Retirada de Encomendas.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isPickupEnabled = enabled;
    });

    await widget.catalogController.savePickupConfig(
      isPickupEnabled: enabled,
      pickupAddress: address,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BellaColors.successGreen,
        content: Row(
          children: [
            const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                enabled
                    ? 'Retirada no local ATIVADA! Endereço: $address'
                    : 'Retirada no local DESATIVADA (apenas Entrega ativa no site).',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSaveCoupon() async {
    final code = _couponCodeController.text.trim().toUpperCase();
    if (code.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BellaColors.errorRed,
          content: Text(
            'Informe um código para o cupom (ex: VOLTE10).',
          ),
        ),
      );
      return;
    }

    double discountVal = 0.0;
    if (_selectedCouponType != CouponDiscountType.freeShipping) {
      final cleanVal = _couponValueController.text
          .replaceAll('R\$', '')
          .replaceAll('%', '')
          .replaceAll(' ', '')
          .replaceAll(',', '.')
          .trim();
      final parsedVal = double.tryParse(cleanVal);
      if (parsedVal == null || parsedVal <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: BellaColors.errorRed,
            content: Text('Informe o valor do desconto (ex: 10 ou 5,00).'),
          ),
        );
        return;
      }
      discountVal = parsedVal;
    }

    final cleanMin = _couponMinOrderController.text
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();
    final minOrder = cleanMin.isNotEmpty ? (double.tryParse(cleanMin) ?? 0.0) : 0.0;

    final existing = widget.catalogController.findCouponByCode(code);
    final coupon = CouponModel(
      code: code,
      discountType: _selectedCouponType,
      discountValue: discountVal,
      minOrderValue: minOrder,
      oncePerCustomer: _couponOncePerCustomer,
      isActive: true,
      usedByPhones: existing?.usedByPhones ?? const [],
    );

    await widget.catalogController.saveCoupon(coupon);
    if (!mounted) return;

    _couponCodeController.clear();
    _couponValueController.clear();
    _couponMinOrderController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BellaColors.successGreen,
        content: Row(
          children: [
            const Icon(Icons.local_offer_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cupom "$code" (${coupon.benefitSummary}) salvo e ativo!',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSaveAdminPin() async {
    final newPin = _adminPinController.text.trim();
    if (newPin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BellaColors.errorRed,
          content: Text('O PIN deve ter pelo menos 4 caracteres.'),
        ),
      );
      return;
    }

    await widget.catalogController.saveAdminPin(newPin);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BellaColors.successGreen,
        content: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Novo PIN de acesso ("$newPin") salvo com sucesso!'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteOrder(CheckoutOrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.delete_forever_rounded,
                color: BellaColors.errorRed,
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Apagar Pedido?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            'Deseja remover permanentemente o pedido de "${order.customerName}" (${CurrencyFormatter.formatBRL(order.total)})?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              key: const ValueKey('confirm_delete_order_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BellaColors.errorRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Apagar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await widget.catalogController.deleteOrder(order.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BellaColors.darkChocolate,
        content: Text('Pedido de "${order.customerName}" removido.'),
      ),
    );
  }

  Future<void> _confirmClearCompletedOrders(int completedCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.cleaning_services_rounded,
                color: BellaColors.errorRed,
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Limpar Histórico de Concluídos?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            'Deseja apagar todos os $completedCount pedidos já concluídos do histórico?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              key: const ValueKey('confirm_clear_completed_orders_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BellaColors.errorRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Limpar Histórico'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await widget.catalogController.clearCompletedOrders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: BellaColors.successGreen,
        content: Text('Histórico de pedidos concluídos limpo com sucesso!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 580;

    // Tema compacto para o Painel Admin (fontes e botões menores e sem sobreposição no celular)
    final compactTheme = baseTheme.copyWith(
      visualDensity: VisualDensity.compact,
      textTheme: baseTheme.textTheme.copyWith(
        titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
          fontSize: isMobile ? 15.5 : 17.5,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
          fontSize: isMobile ? 14.0 : 15.0,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
          fontSize: isMobile ? 13.5 : 14.5,
        ),
        bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
          fontSize: isMobile ? 12.5 : 13.5,
        ),
        labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
          fontSize: isMobile ? 12.5 : 13.5,
        ),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        labelStyle: const TextStyle(
          color: BellaColors.mediumBrown,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          color: BellaColors.softCocoa,
          fontSize: 12.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BellaColors.pinkPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BellaColors.pinkPrimary,
          visualDensity: VisualDensity.compact,
          side: const BorderSide(color: BellaColors.pinkPrimary, width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    final textTheme = compactTheme.textTheme;

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.05,
        ),
      ),
      child: Theme(
        data: compactTheme,
        child: ListenableBuilder(
          listenable: widget.catalogController,
          builder: (context, _) {
            final products = widget.catalogController.allProducts;
            final orders = widget.catalogController.orders;
            final coupons = widget.catalogController.coupons;
            final categories = _selectableCategories;
            final effectiveSelectedCategory =
                categories.any((c) => c.id == _selectedCategoryId)
                    ? _selectedCategoryId
                    : categories.first.id;

            return Scaffold(
              appBar: AppBar(
                toolbarHeight: 48,
                title: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      color: BellaColors.pinkPrimary,
                      size: 19,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Painel Bella Lu Doces',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (!kIsWeb)
                    IconButton(
                      key: const ValueKey('admin_open_cloud_panel_button'),
                      tooltip: 'Abrir versão em nuvem (/painel)',
                      onPressed: _openLiveCloudPanel,
                      icon: const Icon(
                        Icons.cloud_sync_rounded,
                        color: BellaColors.pinkPrimary,
                        size: 20,
                      ),
                    ),
                  IconButton(
                    key: const ValueKey('admin_sync_catalog_button'),
                    tooltip: 'Sincronizar com a Nuvem',
                    onPressed: () {
                      widget.catalogController.loadCatalog();
                      _checkRemoteCloudUpdate();
                    },
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: BellaColors.darkChocolate,
                      size: 20,
                    ),
                  ),
                ],
              ),
              body: SafeArea(
                top: false,
                bottom: true,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: SingleChildScrollView(
                      key: const ValueKey('admin_scroll_view'),
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        12,
                        10,
                        12,
                        MediaQuery.viewPaddingOf(context).bottom + 64,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        if (_hasRemoteCloudUpdate) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: BellaColors.pinkSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: BellaColors.pinkPrimary,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.system_update_rounded,
                                      color: BellaColors.pinkPrimary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Nova atualização disponível no Painel ($_remoteCloudVersionLabel)!',
                                        style: textTheme.titleMedium?.copyWith(
                                          color: BellaColors.darkChocolate,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Toque abaixo para baixar e instalar a nova versão do aplicativo direto do GitHub, ou abra o painel na nuvem.',
                                  style: textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _downloadLatestAdminApk,
                                      icon: const Icon(
                                        Icons.download_rounded,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Baixar e Atualizar APK',
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _openLiveCloudPanel,
                                      icon: const Icon(
                                        Icons.open_in_full_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Abrir na Nuvem'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        // 1. Formulário de Cadastro de Novo Produto
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.add_business_rounded,
                                        color: BellaColors.pinkPrimary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Cadastrar Novo Produto no Catálogo',
                                          style: textTheme.titleLarge,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Nome do Produto (Linha inteira para não cortar no celular)
                                  TextFormField(
                                    key: const ValueKey('admin_name_input'),
                                    controller: _nameController,
                                    style: const TextStyle(fontSize: 13.5),
                                    decoration: const InputDecoration(
                                      labelText: 'Nome do Produto *',
                                      hintText:
                                          'Ex: Pipoca Gourmet, Bolo Caseiro, Cesta...',
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Informe o nome do produto.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),

                                  // Preço Principal e 2º Preço Opcional lado a lado
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          key: const ValueKey(
                                            'admin_price_input',
                                          ),
                                          controller: _priceController,
                                          style:
                                              const TextStyle(fontSize: 13.5),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                            decimal: true,
                                          ),
                                          decoration: const InputDecoration(
                                            labelText: 'Preço (R\$) *',
                                            hintText: 'Ex: 20,00',
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Informe o valor.';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                          key: const ValueKey(
                                            'admin_secondary_price_input',
                                          ),
                                          controller: _secondaryPriceController,
                                          style:
                                              const TextStyle(fontSize: 13.5),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                            decimal: true,
                                          ),
                                          decoration: const InputDecoration(
                                            labelText: '2º Preço (Opcional)',
                                            hintText: 'Ex: 25,00',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Categoria + Botão "+ Nova Categoria" (Empilhados no Mobile para nunca sobrepor!)
                                  DropdownButtonFormField<String>(
                                    key: const ValueKey(
                                      'admin_category_dropdown',
                                    ),
                                    isExpanded: true,
                                    initialValue: effectiveSelectedCategory,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: BellaColors.darkChocolate,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Categoria no Cardápio',
                                    ),
                                    items: categories.map((cat) {
                                      return DropdownMenuItem(
                                        value: cat.id,
                                        child: Row(
                                          children: [
                                            Icon(
                                              cat.iconData,
                                              size: 16,
                                              color: BellaColors.pinkPrimary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                cat.name,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(
                                          () => _selectedCategoryId = value,
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      key: const ValueKey(
                                        'admin_quick_add_category_button',
                                      ),
                                      onPressed: _showQuickCategoryDialog,
                                      icon: const Icon(
                                        Icons.add_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('+ Nova Categoria'),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Sabores / Opções separados por vírgula
                                  TextFormField(
                                    key: const ValueKey('admin_flavors_input'),
                                    controller: _flavorsController,
                                    style: const TextStyle(fontSize: 13.5),
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Sabores / Opções (separados por vírgula) *',
                                      hintText:
                                          'Ex: Oreo, Ninho, Ninho com Nutella',
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Informe pelo menos 1 sabor ou opção.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),

                                  // Descrição do Produto
                                  TextFormField(
                                    key: const ValueKey('admin_desc_input'),
                                    controller: _descriptionController,
                                    style: const TextStyle(fontSize: 13.5),
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText: 'Descrição do Produto',
                                      hintText:
                                          'Ex: Detalhes do produto, peso, ingredientes...',
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Upload de Foto
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          key: const ValueKey(
                                            'admin_image_url_input',
                                          ),
                                          controller: _imageUrlController,
                                          style:
                                              const TextStyle(fontSize: 12.5),
                                          onChanged: (_) => setState(() {}),
                                          decoration: const InputDecoration(
                                            labelText: 'Foto do Produto',
                                            hintText: 'Toque em Escolher Foto',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        key: const ValueKey(
                                          'admin_pick_photo_button',
                                        ),
                                        onPressed: _isUploadingPhoto
                                            ? null
                                            : _handlePickAndUploadPhoto,
                                        icon: _isUploadingPhoto
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.add_a_photo_outlined,
                                                size: 16,
                                              ),
                                        label: const Text('Escolher Foto'),
                                      ),
                                    ],
                                  ),

                                  if (_imageUrlController.text
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: ProductIllustrationBanner(
                                        product: ProductModel(
                                          id: 'preview',
                                          name: 'Preview',
                                          description: '',
                                          imageUrl:
                                              _imageUrlController.text.trim(),
                                          basePrice: 0,
                                          categoryId: effectiveSelectedCategory,
                                          categoryName: '',
                                          options: const [],
                                        ),
                                        height: 115,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),

                                  ElevatedButton.icon(
                                    key: const ValueKey(
                                      'admin_save_product_button',
                                    ),
                                    onPressed: _isSavingProduct
                                        ? null
                                        : _handleSaveNewProduct,
                                    icon: const Icon(
                                      Icons.publish_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Publicar Novo Produto no Cardápio',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 2. Gestão e Edição de Produtos Atuais (Com botão explícito "Editar" e "Excluir")
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Produtos Cadastrados (${products.length})',
                                        style: textTheme.titleLarge,
                                      ),
                                    ),
                                    const BellaBadge(
                                      label: 'Tempo Real',
                                      icon: Icons.sync_rounded,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Toque em "Editar" para alterar nome, valor, sabores ou foto de qualquer produto no ar.',
                                  style: textTheme.bodyMedium,
                                ),
                                const Divider(height: 18),
                                ...products.map((product) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: product.isAvailable
                                            ? Colors.white
                                            : BellaColors.pinkSoft
                                                .withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: BellaColors.pinkBorder,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      product.name,
                                                      style: textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${product.categoryName} • ${CurrencyFormatter.formatBRL(product.basePrice)}${product.secondaryPrice != null ? " | ${CurrencyFormatter.formatBRL(product.secondaryPrice!)}" : ""}',
                                                      style: textTheme
                                                          .labelLarge
                                                          ?.copyWith(
                                                        color: BellaColors
                                                            .pinkPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Sabores: ${product.flavorNames.join(", ")}',
                                                      style:
                                                          textTheme.bodyMedium,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Transform.scale(
                                                    scale: 0.82,
                                                    child: Switch(
                                                      key: ValueKey(
                                                        'toggle_avail_${product.id}',
                                                      ),
                                                      value:
                                                          product.isAvailable,
                                                      activeThumbColor:
                                                          BellaColors
                                                              .successGreen,
                                                      onChanged: (val) {
                                                        widget.catalogController
                                                            .toggleAvailability(
                                                          product.id,
                                                          val,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  Text(
                                                    product.isAvailable
                                                        ? 'Ativo'
                                                        : 'Pausado',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              OutlinedButton.icon(
                                                key: ValueKey(
                                                  'edit_prod_${product.id}',
                                                ),
                                                onPressed: () =>
                                                    _showEditProductDialog(
                                                  product,
                                                ),
                                                icon: const Icon(
                                                  Icons.edit_rounded,
                                                  size: 15,
                                                ),
                                                label: const Text(
                                                  'Editar Produto',
                                                ),
                                              ),
                                              OutlinedButton.icon(
                                                key: ValueKey(
                                                  'delete_prod_${product.id}',
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      BellaColors.errorRed,
                                                  side: const BorderSide(
                                                    color: BellaColors.errorRed,
                                                    width: 1.1,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _confirmDeleteProduct(
                                                  product,
                                                ),
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 15,
                                                ),
                                                label: const Text('Excluir'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 3. Gerenciar e Criar Novas Categorias do Catálogo
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.category_rounded,
                                      color: BellaColors.pinkPrimary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Categorias do Cardápio (${categories.length})',
                                        style: textTheme.titleLarge,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Adicione novas categorias conforme o catálogo expandir.',
                                  style: textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: categories.map((cat) {
                                    return Chip(
                                      visualDensity: VisualDensity.compact,
                                      avatar: Icon(
                                        cat.iconData,
                                        size: 14,
                                        color: BellaColors.pinkPrimary,
                                      ),
                                      label: Text(
                                        cat.name,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  key: const ValueKey(
                                    'admin_new_category_input',
                                  ),
                                  controller: _newCategoryController,
                                  style: const TextStyle(fontSize: 13.5),
                                  onSubmitted: (_) => _handleAddNewCategory(),
                                  decoration: const InputDecoration(
                                    labelText: 'Nome da Nova Categoria',
                                    hintText:
                                        'Ex: Kits Presente, Salgados, Bebidas...',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  key: const ValueKey(
                                    'admin_add_category_button',
                                  ),
                                  onPressed: _handleAddNewCategory,
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Criar Categoria'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 4. Pedidos Recebidos da Vitrine (Automático + Histórico e Exclusão)
                        Builder(
                          builder: (context) {
                            final pendingOrders = orders
                                .where((o) => !o.isCompleted)
                                .toList();
                            final completedOrders = orders
                                .where((o) => o.isCompleted)
                                .toList();
                            final displayedOrders = _ordersTab == 'pending'
                                ? pendingOrders
                                : _ordersTab == 'completed'
                                    ? completedOrders
                                    : orders;

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.receipt_long_rounded,
                                                color: BellaColors.pinkPrimary,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Pedidos Recebidos (${orders.length})',
                                                  style: textTheme.titleLarge,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        TextButton.icon(
                                          key: const ValueKey(
                                            'admin_refresh_orders_button',
                                          ),
                                          onPressed: widget
                                              .catalogController.refreshOrders,
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Atualizar',
                                            style: TextStyle(fontSize: 12.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Marque a chave para enviar ao Histórico de Concluídos ou toque na lixeira para apagar pedidos.',
                                      style: textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        ChoiceChip(
                                          key: const ValueKey(
                                            'orders_tab_pending',
                                          ),
                                          label: Text(
                                            'Em Aberto (${pendingOrders.length})',
                                          ),
                                          selected: _ordersTab == 'pending',
                                          selectedColor:
                                              BellaColors.pinkPrimary,
                                          labelStyle: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _ordersTab == 'pending'
                                                ? Colors.white
                                                : BellaColors.darkChocolate,
                                          ),
                                          onSelected: (_) {
                                            setState(
                                              () => _ordersTab = 'pending',
                                            );
                                          },
                                        ),
                                        ChoiceChip(
                                          key: const ValueKey(
                                            'orders_tab_completed',
                                          ),
                                          label: Text(
                                            'Histórico (${completedOrders.length})',
                                          ),
                                          selected: _ordersTab == 'completed',
                                          selectedColor:
                                              BellaColors.pinkPrimary,
                                          labelStyle: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _ordersTab == 'completed'
                                                ? Colors.white
                                                : BellaColors.darkChocolate,
                                          ),
                                          onSelected: (_) {
                                            setState(
                                              () => _ordersTab = 'completed',
                                            );
                                          },
                                        ),
                                        ChoiceChip(
                                          key: const ValueKey(
                                            'orders_tab_all',
                                          ),
                                          label: Text(
                                            'Todos (${orders.length})',
                                          ),
                                          selected: _ordersTab == 'all',
                                          selectedColor:
                                              BellaColors.pinkPrimary,
                                          labelStyle: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _ordersTab == 'all'
                                                ? Colors.white
                                                : BellaColors.darkChocolate,
                                          ),
                                          onSelected: (_) {
                                            setState(
                                              () => _ordersTab = 'all',
                                            );
                                          },
                                        ),
                                        if (completedOrders.isNotEmpty)
                                          TextButton.icon(
                                            key: const ValueKey(
                                              'clear_completed_orders_button',
                                            ),
                                            onPressed: () =>
                                                _confirmClearCompletedOrders(
                                              completedOrders.length,
                                            ),
                                            icon: const Icon(
                                              Icons.cleaning_services_rounded,
                                              size: 15,
                                              color: BellaColors.errorRed,
                                            ),
                                            label: const Text(
                                              'Limpar Histórico',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: BellaColors.errorRed,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const Divider(height: 18),
                                    if (displayedOrders.isEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: BellaColors.pinkSoft,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _ordersTab == 'pending'
                                              ? 'Nenhum pedido pendente em aberto.'
                                              : _ordersTab == 'completed'
                                                  ? 'Nenhum pedido concluído no histórico.'
                                                  : 'Nenhum pedido registrado ainda.',
                                          textAlign: TextAlign.center,
                                          style: textTheme.bodyMedium,
                                        ),
                                      )
                                    else
                                      ...displayedOrders.map((order) {
                                        final isDelivery =
                                            order.deliveryMethod ==
                                                DeliveryMethod.delivery;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: order.isCompleted
                                                  ? BellaColors.pinkSoft
                                                      .withValues(
                                                      alpha: 0.45,
                                                    )
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: order.isCompleted
                                                    ? BellaColors.pinkBorder
                                                    : BellaColors.pinkPrimary,
                                                width:
                                                    order.isCompleted ? 1 : 1.4,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '${order.customerName} • ${order.customerPhone}',
                                                        style: textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          order.isCompleted
                                                              ? 'Concluído'
                                                              : 'Em aberto',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: order
                                                                    .isCompleted
                                                                ? BellaColors
                                                                    .successGreen
                                                                : BellaColors
                                                                    .mediumBrown,
                                                          ),
                                                        ),
                                                        Transform.scale(
                                                          scale: 0.85,
                                                          child: Switch(
                                                            key: ValueKey(
                                                              'toggle_order_${order.id}',
                                                            ),
                                                            value: order
                                                                .isCompleted,
                                                            activeThumbColor:
                                                                BellaColors
                                                                    .successGreen,
                                                            onChanged: (val) {
                                                              widget
                                                                  .catalogController
                                                                  .toggleOrderCompleted(
                                                                order.id,
                                                                val,
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                        IconButton(
                                                          key: ValueKey(
                                                            'delete_order_${order.id}',
                                                          ),
                                                          tooltip:
                                                              'Apagar pedido',
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                          onPressed: () =>
                                                              _confirmDeleteOrder(
                                                            order,
                                                          ),
                                                          icon: const Icon(
                                                            Icons
                                                                .delete_outline_rounded,
                                                            color: BellaColors
                                                                .errorRed,
                                                            size: 19,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                ...order.formattedItemLines.map(
                                                  (line) => Text(
                                                    '• $line',
                                                    style: textTheme.bodyMedium,
                                                  ),
                                                ),
                                                if (isDelivery)
                                                  Text(
                                                    '• Taxa de entrega: ${CurrencyFormatter.formatBRL(order.deliveryFee)} (${order.streetAddress}, ${order.neighborhood})',
                                                    style: textTheme.bodyMedium,
                                                  )
                                                else
                                                  Text(
                                                    order.pickupAddress
                                                            .trim()
                                                            .isNotEmpty
                                                        ? '• Retirada no local: ${order.pickupAddress.trim()}'
                                                        : '• Retirada: Combinar com a loja',
                                                    style: textTheme.bodyMedium,
                                                  ),
                                                if (order.discountAmount > 0)
                                                  Text(
                                                    '• Cupom (${order.couponCode}): - ${CurrencyFormatter.formatBRL(order.discountAmount)}',
                                                    style: textTheme.bodyMedium
                                                        ?.copyWith(
                                                      color: BellaColors
                                                          .successGreen,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Pagamento: ${order.paymentMethod.label} • Total: ${CurrencyFormatter.formatBRL(order.total)}',
                                                  style: textTheme.labelLarge
                                                      ?.copyWith(
                                                    color:
                                                        BellaColors.pinkPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // 5. Configuração da Chave Pix da Loja
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.qr_code_rounded,
                                      color: BellaColors.pinkPrimary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Configuração da Chave Pix da Loja',
                                        style: textTheme.titleLarge,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Altere a Chave Pix, o titular e o banco exibidos aos clientes.',
                                  style: textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  key: const ValueKey('admin_pix_key_input'),
                                  controller: _pixKeyController,
                                  style: const TextStyle(fontSize: 13.5),
                                  decoration: const InputDecoration(
                                    labelText: 'Chave Pix (Celular/CPF/CNPJ)',
                                    hintText: 'Ex: 34987193964',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  key: const ValueKey('admin_pix_holder_input'),
                                  controller: _pixHolderController,
                                  style: const TextStyle(fontSize: 13.5),
                                  decoration: const InputDecoration(
                                    labelText: 'Nome do Titular / Favorecido',
                                    hintText: 'Ex: Lucineide da Silva',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  key: const ValueKey('admin_pix_bank_input'),
                                  controller: _pixBankController,
                                  style: const TextStyle(fontSize: 13.5),
                                  decoration: const InputDecoration(
                                    labelText: 'Banco / Instituição Financeira',
                                    hintText: 'Ex: Nubank, Caixa...',
                                    prefixIcon: Icon(
                                      Icons.account_balance_rounded,
                                      color: BellaColors.pinkPrimary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  key: const ValueKey('admin_save_pix_button'),
                                  onPressed: _handleSavePixConfig,
                                  icon:
                                      const Icon(Icons.save_rounded, size: 18),
                                  label: const Text('Salvar Chave Pix'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 5.5. Taxa de Entrega e Retirada no Local
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.local_shipping_rounded,
                                      color: BellaColors.pinkPrimary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Taxa de Entrega (${CurrencyFormatter.formatBRL(widget.catalogController.deliveryFee)})',
                                        style: textTheme.titleLarge,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Altere o valor cobrado nas entregas em domicílio no cardápio.',
                                  style: textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  key: const ValueKey(
                                    'admin_delivery_fee_input',
                                  ),
                                  controller: _deliveryFeeController,
                                  style: const TextStyle(fontSize: 13.5),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Valor da Taxa de Entrega (R\$)',
                                    hintText: 'Ex: 10,00',
                                    prefixIcon: Icon(
                                      Icons.delivery_dining_rounded,
                                      color: BellaColors.pinkPrimary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  key: const ValueKey(
                                    'admin_save_delivery_fee_button',
                                  ),
                                  onPressed: _handleSaveDeliveryFee,
                                  icon:
                                      const Icon(Icons.save_rounded, size: 18),
                                  label: const Text('Salvar Taxa de Entrega'),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Divider(height: 1),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.storefront_rounded,
                                      color: BellaColors.pinkPrimary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Retirada de Encomendas no Local',
                                        style: textTheme.titleLarge,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _isPickupEnabled
                                            ? BellaColors.successGreen
                                                .withValues(alpha: 0.14)
                                            : BellaColors.pinkSoft,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        _isPickupEnabled
                                            ? 'Ativada'
                                            : 'Desativada',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: _isPickupEnabled
                                              ? BellaColors.successGreen
                                              : BellaColors.mediumBrown,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ative quando o espaço físico de retirada estiver pronto e informe o endereço para o cliente.',
                                  style: textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                Material(
                                  color: BellaColors.pinkSoft.withValues(
                                    alpha: 0.55,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                      color: BellaColors.pinkBorder,
                                    ),
                                  ),
                                  child: SwitchListTile(
                                    key: const ValueKey(
                                      'admin_pickup_enabled_switch',
                                    ),
                                    dense: true,
                                    activeThumbColor: BellaColors.successGreen,
                                    title: const Text(
                                      'Permitir Retirada no Local no Checkout',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _isPickupEnabled
                                          ? 'Clientes podem escolher entre Entrega ou Retirada.'
                                          : 'Apenas Entrega em Domicílio aparece no site.',
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                    value: _isPickupEnabled,
                                    onChanged: (val) {
                                      setState(() {
                                        _isPickupEnabled = val;
                                      });
                                      if (!val) {
                                        _handleSavePickupConfig(
                                          overrideEnabled: false,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  key: const ValueKey(
                                    'admin_pickup_address_input',
                                  ),
                                  controller: _pickupAddressController,
                                  style: const TextStyle(fontSize: 13.5),
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Endereço Físico para Retirada',
                                    hintText:
                                        'Ex: Rua das Rosas, 250 - Bairro Centro',
                                    prefixIcon: Icon(
                                      Icons.location_on_rounded,
                                      color: BellaColors.pinkPrimary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  key: const ValueKey(
                                    'admin_save_pickup_config_button',
                                  ),
                                  onPressed: () => _handleSavePickupConfig(),
                                  icon:
                                      const Icon(Icons.save_rounded, size: 18),
                                  label: const Text(
                                    'Salvar Configuração de Retirada',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 5.6. Cupons de Desconto (Fidelidade / Próxima Compra)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.local_offer_rounded,
                                            color: BellaColors.pinkPrimary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Cupons de Desconto (${coupons.length})',
                                              style: textTheme.titleLarge,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const BellaBadge(
                                      label: 'Fidelidade',
                                      icon: Icons.card_giftcard_rounded,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Crie cupons para fidelizar clientes na próxima compra (ex: VOLTE10).',
                                  style: textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  key: const ValueKey(
                                    'admin_coupon_code_input',
                                  ),
                                  controller: _couponCodeController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  style: const TextStyle(fontSize: 13.5),
                                  decoration: const InputDecoration(
                                    labelText: 'Código do Cupom *',
                                    hintText: 'Ex: VOLTE10, DOCE5, FRETEGRATIS',
                                    prefixIcon: Icon(
                                      Icons.confirmation_number_rounded,
                                      color: BellaColors.pinkPrimary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<CouponDiscountType>(
                                  key: const ValueKey(
                                    'admin_coupon_type_dropdown',
                                  ),
                                  initialValue: _selectedCouponType,
                                  isExpanded: true,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: BellaColors.darkChocolate,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo de Desconto',
                                  ),
                                  items: CouponDiscountType.values.map((t) {
                                    return DropdownMenuItem(
                                      value: t,
                                      child: Text(t.label),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(
                                        () => _selectedCouponType = val,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (_selectedCouponType !=
                                        CouponDiscountType.freeShipping) ...[
                                      Expanded(
                                        child: TextField(
                                          key: const ValueKey(
                                            'admin_coupon_value_input',
                                          ),
                                          controller: _couponValueController,
                                          style:
                                              const TextStyle(fontSize: 13.5),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                            decimal: true,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: _selectedCouponType ==
                                                    CouponDiscountType
                                                        .percentage
                                                ? 'Desconto (%) *'
                                                : 'Desconto (R\$) *',
                                            hintText: _selectedCouponType ==
                                                    CouponDiscountType
                                                        .percentage
                                                ? 'Ex: 10'
                                                : 'Ex: 5,00',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: TextField(
                                        key: const ValueKey(
                                          'admin_coupon_min_order_input',
                                        ),
                                        controller: _couponMinOrderController,
                                        style: const TextStyle(fontSize: 13.5),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Pedido Mínimo (Opcional)',
                                          hintText: 'Ex: 30,00',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(
                                    'Uso único por cliente (por telefone)',
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: BellaColors.darkChocolate,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Impede que o mesmo telefone use o cupom mais de 1 vez.',
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  value: _couponOncePerCustomer,
                                  activeThumbColor: BellaColors.pinkPrimary,
                                  onChanged: (val) {
                                    setState(
                                      () => _couponOncePerCustomer = val,
                                    );
                                  },
                                ),
                                const SizedBox(height: 6),
                                ElevatedButton.icon(
                                  key: const ValueKey(
                                    'admin_save_coupon_button',
                                  ),
                                  onPressed: _handleSaveCoupon,
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Criar / Salvar Cupom'),
                                ),
                                if (coupons.isNotEmpty) ...[
                                  const Divider(height: 20),
                                  Text(
                                    'Cupons Cadastrados:',
                                    style: textTheme.labelLarge?.copyWith(
                                      color: BellaColors.darkChocolate,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...coupons.map((coupon) {
                                    final minOrderText = coupon.minOrderValue >
                                            0
                                        ? ' • Mín: ${CurrencyFormatter.formatBRL(coupon.minOrderValue)}'
                                        : '';
                                    final usageText = coupon.oncePerCustomer
                                        ? ' • Uso único (${coupon.usedByPhones.length} usos)'
                                        : ' • Uso livre';
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: coupon.isActive
                                              ? Colors.white
                                              : BellaColors.pinkSoft.withValues(
                                                  alpha: 0.4,
                                                ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: coupon.isActive
                                                ? BellaColors.pinkPrimary
                                                : BellaColors.pinkBorder,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${coupon.normalizedCode} • ${coupon.benefitSummary}',
                                                    style: textTheme.titleMedium
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: coupon.isActive
                                                          ? BellaColors
                                                              .darkChocolate
                                                          : BellaColors
                                                              .mediumBrown,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${coupon.isActive ? "Ativo" : "Pausado"}$minOrderText$usageText',
                                                    style: textTheme.bodyMedium
                                                        ?.copyWith(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Transform.scale(
                                              scale: 0.85,
                                              child: Switch(
                                                key: ValueKey(
                                                  'toggle_coupon_${coupon.normalizedCode}',
                                                ),
                                                value: coupon.isActive,
                                                activeThumbColor:
                                                    BellaColors.successGreen,
                                                onChanged: (val) {
                                                  widget.catalogController
                                                      .toggleCouponActive(
                                                    coupon.normalizedCode,
                                                    val,
                                                  );
                                                },
                                              ),
                                            ),
                                            IconButton(
                                              key: ValueKey(
                                                'delete_coupon_${coupon.normalizedCode}',
                                              ),
                                              tooltip: 'Excluir cupom',
                                              onPressed: () {
                                                widget.catalogController
                                                    .deleteCoupon(
                                                  coupon.normalizedCode,
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: BellaColors.errorRed,
                                                size: 19,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 6. Segurança do Painel (Alterar PIN / Senha de Acesso)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.lock_person_rounded,
                                      color: BellaColors.pinkPrimary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Segurança do Painel (Alterar PIN)',
                                        style: textTheme.titleLarge,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Altere a senha/PIN exigida para entrar no painel.',
                                  style: textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  key: const ValueKey('admin_new_pin_input'),
                                  controller: _adminPinController,
                                  style: const TextStyle(fontSize: 13.5),
                                  decoration: const InputDecoration(
                                    labelText: 'Novo PIN / Senha do Painel',
                                    hintText: 'Ex: 2026',
                                    prefixIcon: Icon(
                                      Icons.key_rounded,
                                      color: BellaColors.pinkPrimary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  key: const ValueKey('admin_save_pin_button'),
                                  onPressed: _handleSaveAdminPin,
                                  icon:
                                      const Icon(Icons.save_rounded, size: 18),
                                  label: const Text('Salvar Novo PIN'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: SunflowerDeveloperBadge(
                            compact: true,
                            labelPrefix: 'Suporte Técnico •',
                            actionHint: 'Falar com a Sunflower Development',
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          },
        ),
      ),
    );
  }
}
