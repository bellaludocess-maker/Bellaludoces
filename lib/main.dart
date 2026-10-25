import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/bella_colors.dart';
import 'core/theme/bella_theme.dart';
import 'core/widgets/add_to_cart_fly_overlay.dart';
import 'core/widgets/mobile_preview_wrapper.dart';
import 'core/widgets/whatsapp_logo_icon.dart';
import 'modules/cart/controllers/cart_controller.dart';
import 'modules/cart/views/cart_bottom_sheet.dart';
import 'modules/cart/views/product_options_sheet.dart';
import 'modules/cart/views/widgets/floating_cart_bar.dart';
import 'modules/catalog/controllers/catalog_controller.dart';
import 'modules/catalog/data/catalog_repository.dart';
import 'modules/catalog/models/product_model.dart';
import 'modules/catalog/views/catalog_screen.dart';
import 'modules/checkout/services/whatsapp_order_service.dart';
import 'modules/checkout/views/checkout_screen.dart';
import 'modules/external/config/cloud_config.dart';
import 'modules/external/firebase/firestore_catalog_repository.dart';

/// Entrypoint Oficial da Vitrine Pública de Clientes (`www.bellaludoces.com.br`).
/// 100% dedicado à experiência de compra do cliente final (sem expor painel admin).
/// O Painel Administrativo roda de forma independente via `lib/main_admin.dart`.
void main() {
  runApp(const BellaLuDocesApp());
}

class BellaLuDocesApp extends StatefulWidget {
  final CatalogRepository? catalogRepository;
  final WhatsAppOrderService? whatsAppService;
  final CloudConfig? cloudConfig;

  const BellaLuDocesApp({
    super.key,
    this.catalogRepository,
    this.whatsAppService,
    this.cloudConfig,
  });

  @override
  State<BellaLuDocesApp> createState() => _BellaLuDocesAppState();
}

class _BellaLuDocesAppState extends State<BellaLuDocesApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final CloudConfig _cloudConfig;
  late final CatalogController _catalogController;
  late final CartController _cartController;
  bool _isMobilePreviewEnabled = false;
  bool _handledInfinitePayReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cloudConfig = widget.cloudConfig ?? CloudConfig();
    _catalogController = CatalogController(
      repository: widget.catalogRepository ??
          FirestoreCatalogRepository(config: _cloudConfig),
    );
    _cartController = CartController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInfinitePayReturnParameters();
    });
  }

  Future<void> _checkInfinitePayReturnParameters() async {
    if (_handledInfinitePayReturn) return;
    final params = Uri.base.queryParameters;
    final orderNsu = (params['order_nsu'] ?? '').trim();
    final receiptUrl = (params['receipt_url'] ?? '').trim();
    final transactionNsu =
        (params['transaction_nsu'] ?? params['slug'] ?? '').trim();

    if (orderNsu.isEmpty && receiptUrl.isEmpty && transactionNsu.isEmpty) {
      return;
    }
    _handledInfinitePayReturn = true;

    if (orderNsu.isNotEmpty) {
      try {
        await _catalogController.refreshOrders();
        await _catalogController.toggleOrderCompleted(orderNsu, true);
      } catch (_) {}
    }

    final navContext = _navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    await showDialog<void>(
      context: navContext,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.verified_rounded,
                color: BellaColors.successGreen,
                size: 26,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pagamento InfinitePay Concluído!',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                orderNsu.isNotEmpty
                    ? 'Recebemos o retorno do pagamento do seu pedido ($orderNsu).'
                    : 'Recebemos o retorno do seu pagamento via InfinitePay!',
              ),
              const SizedBox(height: 10),
              const Text(
                'Clique no botão abaixo para enviar a confirmação e o comprovante direto no WhatsApp da loja:',
                style: TextStyle(
                  fontSize: 13,
                  color: BellaColors.mediumBrown,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: BellaColors.whatsappGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final textBuffer = StringBuffer(
                  'Olá! Acabei de realizar o pagamento na InfinitePay',
                );
                if (orderNsu.isNotEmpty) {
                  textBuffer.write(' referente ao pedido *$orderNsu*');
                }
                textBuffer.writeln('!');
                if (receiptUrl.isNotEmpty) {
                  textBuffer.writeln('Comprovante: $receiptUrl');
                }
                final waUri = Uri.https(
                  'wa.me',
                  '/${AppConstants.whatsappNumberClean}',
                  {'text': textBuffer.toString().trim()},
                );
                await launchUrl(waUri, mode: LaunchMode.externalApplication);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              icon: const WhatsAppLogoIcon(size: 18),
              label: const Text('Enviar Comprovante no WhatsApp'),
            ),
          ],
        );
      },
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
    _cartController.dispose();
    super.dispose();
  }

  void _openProductOptionsSheet(BuildContext context, ProductModel product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) {
        return ProductOptionsSheet(
          product: product,
          onAddToCart: ({
            required selectedOptions,
            required quantity,
            required notes,
          }) {
            _cartController.addItem(
              product: product,
              selectedOptions: selectedOptions,
              quantity: quantity,
              notes: notes,
            );
            AddToCartFlyOverlay.show(context);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  backgroundColor: BellaColors.darkChocolate,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  content: Row(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: BellaColors.pinkLight,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${quantity}x ${product.name} adicionado à sacola!',
                        ),
                      ),
                    ],
                  ),
                ),
              );
          },
        );
      },
    );
  }

  void _openCheckoutScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CheckoutScreen(
          cartController: _cartController,
          whatsAppService:
              widget.whatsAppService ?? const WhatsAppOrderService(),
          pixKey: _catalogController.pixKey,
          pixHolderName: _catalogController.pixHolderName,
          pixBankName: _catalogController.pixBankName,
          deliveryFee: _catalogController.deliveryFee,
          isPickupEnabled: _catalogController.isPickupEnabled,
          pickupAddress: _catalogController.pickupAddress,
          availableCoupons: _catalogController.coupons,
          onOrderSubmitted: _catalogController.saveOrder,
        ),
      ),
    );
  }

  void _openCartSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) {
        return CartBottomSheet(
          controller: _cartController,
          onProceedToCheckout: () => _openCheckoutScreen(context),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConstants.storeName,
      debugShowCheckedModeBanner: false,
      theme: BellaTheme.lightTheme,
      home: Builder(
        builder: (outerContext) {
          return MobilePreviewWrapper(
            isMobilePreviewEnabled: _isMobilePreviewEnabled,
            onTogglePreview: () {
              setState(
                () => _isMobilePreviewEnabled = !_isMobilePreviewEnabled,
              );
            },
            child: Builder(
              builder: (homeContext) {
                return CatalogScreen(
                  controller: _catalogController,
                  onProductSelected: (product) =>
                      _openProductOptionsSheet(homeContext, product),
                  floatingCartBar: FloatingCartBar(
                    controller: _cartController,
                    onOpenCart: () => _openCartSheet(homeContext),
                  ),
                  appBarActions: [
                    IconButton(
                      key: const ValueKey('appbar_mobile_preview_button'),
                      tooltip: _isMobilePreviewEnabled
                          ? 'Ver em Tela Cheia (PC)'
                          : 'Simular Visão de Celular',
                      onPressed: () {
                        setState(
                          () => _isMobilePreviewEnabled =
                              !_isMobilePreviewEnabled,
                        );
                      },
                      icon: Icon(
                        _isMobilePreviewEnabled
                            ? Icons.desktop_windows_rounded
                            : Icons.smartphone_rounded,
                        color: _isMobilePreviewEnabled
                            ? BellaColors.pinkPrimary
                            : BellaColors.darkChocolate,
                      ),
                    ),
                    ListenableBuilder(
                      listenable: _cartController,
                      builder: (context, _) {
                        final count = _cartController.totalItemsCount;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: IconButton(
                            key: const ValueKey('appbar_cart_button'),
                            tooltip: 'Minha Sacola',
                            onPressed: () => _openCartSheet(homeContext),
                            icon: Badge(
                              isLabelVisible: count > 0,
                              backgroundColor: BellaColors.pinkPrimary,
                              label: Text('$count'),
                              child: const Icon(Icons.shopping_bag_outlined),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
