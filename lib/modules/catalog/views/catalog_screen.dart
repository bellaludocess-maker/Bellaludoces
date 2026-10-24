import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/bella_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/bella_brand_logo.dart';
import '../../../core/widgets/sunflower_developer_badge.dart';
import '../controllers/catalog_controller.dart';
import '../models/product_model.dart';
import 'widgets/product_card.dart';

/// Tela Principal da Vitrine de Produtos da Bella Lu Doces (Módulo 1).
/// Projetada com pontos de extensão (`onProductSelected`, `floatingCartBar`, `appBarActions`)
/// para acoplar os Módulos 2 (Carrinho) e 5 (Admin) sem retrabalho.
class CatalogScreen extends StatelessWidget {
  final CatalogController controller;
  final ValueChanged<ProductModel>? onProductSelected;
  final Widget? floatingCartBar;
  final List<Widget>? appBarActions;

  const CatalogScreen({
    super.key,
    required this.controller,
    this.onProductSelected,
    this.floatingCartBar,
    this.appBarActions,
  });

  void _handleProductTap(BuildContext context, ProductModel product) {
    if (onProductSelected != null) {
      onProductSelected!(product);
      return;
    }

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
                  '${product.name} selecionado! Sabores: ${product.flavorNames.join(", ")}',
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final products = controller.filteredProducts;
        final categories = controller.categories;

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BellaBrandLogo(size: 34),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    AppConstants.storeName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: appBarActions,
          ),
          bottomNavigationBar: floatingCartBar,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: CustomScrollView(
                slivers: [
                  // 1. Banner de Boas-Vindas ("Pronta Entrega Hoje! 💖")
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _StoreHeroBanner(
                        deliveryFee: controller.deliveryFee,
                      ),
                    ),
                  ),

                  // 2. Barra de Busca e Carrossel de Categorias
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            onChanged: controller.updateSearchQuery,
                            decoration: const InputDecoration(
                              hintText:
                                  'Buscar doce ou sabor (ex: Ninho, Oreo, Cenoura)...',
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: BellaColors.pinkPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final category = categories[index];
                                final isSelected =
                                    controller.selectedCategoryId ==
                                        category.id;

                                return ChoiceChip(
                                  key: ValueKey('category_${category.id}'),
                                  showCheckmark: false,
                                  avatar: Icon(
                                    category.iconData,
                                    size: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : BellaColors.pinkPrimary,
                                  ),
                                  label: Text(category.name),
                                  selected: isSelected,
                                  onSelected: (_) =>
                                      controller.selectCategory(category.id),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // 3. Listagem de Produtos do Catálogo (Adaptativa: 1 coluna no Mobile, Grid no PC/Tablet)
                  if (controller.isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (products.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.cookie_outlined,
                              size: 48,
                              color: BellaColors.pinkLight,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhum doce encontrado para essa busca.',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktopOrTablet =
                              constraints.crossAxisExtent >= 680;

                          if (!isDesktopOrTablet) {
                            // Layout Mobile: 1 coluna vertical fluida
                            return SliverList.separated(
                              itemCount: products.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 18),
                              itemBuilder: (context, index) {
                                final product = products[index];
                                return ProductCard(
                                  key: ValueKey('product_${product.id}'),
                                  product: product,
                                  animationIndex: index,
                                  onSelect: () =>
                                      _handleProductTap(context, product),
                                );
                              },
                            );
                          }

                          // Layout PC / Tablet: Grid de 2 colunas lado a lado com alturas sincronizadas
                          final rowsCount = (products.length / 2).ceil();
                          return SliverList.separated(
                            itemCount: rowsCount,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 18),
                            itemBuilder: (context, rowIndex) {
                              final firstIndex = rowIndex * 2;
                              final secondIndex = firstIndex + 1;
                              final firstProduct = products[firstIndex];
                              final secondProduct =
                                  secondIndex < products.length
                                      ? products[secondIndex]
                                      : null;

                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ProductCard(
                                        key: ValueKey(
                                            'product_${firstProduct.id}'),
                                        product: firstProduct,
                                        animationIndex: firstIndex,
                                        onSelect: () => _handleProductTap(
                                            context, firstProduct),
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: secondProduct != null
                                          ? ProductCard(
                                              key: ValueKey(
                                                  'product_${secondProduct.id}'),
                                              product: secondProduct,
                                              animationIndex: secondIndex,
                                              onSelect: () => _handleProductTap(
                                                  context, secondProduct),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                  // 4. Rodapé com Informações de Entrega, WhatsApp e Instagram
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        24,
                        16,
                        MediaQuery.viewPaddingOf(context).bottom + 56,
                      ),
                      child: _StoreFooterBanner(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StoreHeroBanner extends StatefulWidget {
  final double deliveryFee;

  const _StoreHeroBanner({
    this.deliveryFee = AppConstants.defaultDeliveryFee,
  });

  @override
  State<_StoreHeroBanner> createState() => _StoreHeroBannerState();
}

class _StoreHeroBannerState extends State<_StoreHeroBanner> {
  int _pulseCount = 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => setState(() => _pulseCount++),
      child: TweenAnimationBuilder<double>(
        key: ValueKey('hero_pulse_$_pulseCount'),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1450),
        curve: Curves.easeOutBack,
        builder: (context, animVal, child) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: BellaColors.headerGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: BellaColors.pinkBorder, width: 1.5),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Corações vetoriais decorativos animados no fundo do banner
                Positioned(
                  right: 8,
                  top: -4 + (1.0 - animVal) * 14,
                  child: Opacity(
                    opacity: (animVal * 0.35).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: 0.2,
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: BellaColors.pinkPrimary,
                        size: 26,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 44,
                  top: 16 + (1.0 - animVal) * 20,
                  child: Opacity(
                    opacity: (animVal * 0.22).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: -0.25,
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: BellaColors.pinkPrimary,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                child!,
              ],
            ),
          );
        },
        child: Column(
          children: [
            Row(
              children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey('logo_scale_$_pulseCount'),
                  tween: Tween<double>(begin: 0.78, end: 1.0),
                  duration: const Duration(milliseconds: 1350),
                  curve: Curves.elasticOut,
                  builder: (context, scale, logoChild) {
                    return Transform.scale(scale: scale, child: logoChild);
                  },
                  child: const BellaBrandLogo(size: 82),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TweenAnimationBuilder<double>(
                        key: ValueKey('badge_pulse_$_pulseCount'),
                        tween: Tween<double>(begin: 0.82, end: 1.0),
                        duration: const Duration(milliseconds: 1300),
                        curve: Curves.elasticOut,
                        builder: (context, badgeScale, badgeChild) {
                          return Transform.scale(
                            scale: badgeScale,
                            alignment: Alignment.centerLeft,
                            child: badgeChild,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: BellaColors.promoBannerGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  AppConstants.storePromoHighlight,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppConstants.storeTagline,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: BellaColors.darkChocolate,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppConstants.storeQualityMoto,
                        style: textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BellaColors.pinkBorder),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 18,
                        color: BellaColors.pinkPrimary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Taxa de Entrega: ${CurrencyFormatter.formatBRL(widget.deliveryFee)}',
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    key: const ValueKey('hero_instagram_link'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => launchUrl(
                      Uri.parse(AppConstants.instagramUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.camera_alt_outlined,
                            size: 18,
                            color: BellaColors.pinkPrimary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              AppConstants.instagramHandle,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelLarge?.copyWith(
                                color: BellaColors.pinkDark,
                                decoration: TextDecoration.underline,
                                decorationColor: BellaColors.pinkPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreFooterBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BellaColors.pinkSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BellaColors.pinkBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: BellaColors.pinkPrimary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '"${AppConstants.storeIdeaQuote}"',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: BellaColors.darkChocolate,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: BellaColors.pinkPrimary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              InkWell(
                key: const ValueKey('footer_instagram_link'),
                borderRadius: BorderRadius.circular(20),
                onTap: () => launchUrl(
                  Uri.parse(AppConstants.instagramUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BellaColors.pinkBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 18,
                        color: BellaColors.pinkPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Instagram: ${AppConstants.instagramHandle}',
                        style: textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: BellaColors.pinkBorder, height: 1),
          const SizedBox(height: 14),
          const SunflowerDeveloperBadge(
            labelPrefix: 'Desenvolvido por',
            actionHint: 'Fale com a desenvolvedora • Toque aqui',
          ),
        ],
      ),
    );
  }
}
