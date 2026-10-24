import 'package:flutter/material.dart';
import '../../../../core/theme/bella_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/bella_badge.dart';
import '../../models/product_model.dart';
import 'product_illustration_banner.dart';

/// Card visual do Produto com animação de entrada em cascata (Slide + Fade)
/// e micro-interação de elevação ao toque/mouse.
class ProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback onSelect;
  final int animationIndex;

  const ProductCard({
    super.key,
    required this.product,
    required this.onSelect,
    this.animationIndex = 0,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isHoveredOrPressed = false;

  String _buildPriceText() {
    final base = CurrencyFormatter.formatBRL(widget.product.basePrice);
    if (widget.product.secondaryPrice != null &&
        widget.product.secondaryPrice! > widget.product.basePrice) {
      final secondary =
          CurrencyFormatter.formatBRL(widget.product.secondaryPrice!);
      return '$base  |  $secondary';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final product = widget.product;
    final entranceDurationMs = 850 + (widget.animationIndex.clamp(0, 5) * 200);

    return TweenAnimationBuilder<double>(
      key: ValueKey('entrance_${product.id}_${product.categoryId}'),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: entranceDurationMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - value) * 32),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHoveredOrPressed = true),
        onExit: (_) => setState(() => _isHoveredOrPressed = false),
        child: AnimatedScale(
          scale: _isHoveredOrPressed && product.isAvailable ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: BellaColors.pinkPrimary.withValues(
                    alpha: _isHoveredOrPressed ? 0.18 : 0.06,
                  ),
                  blurRadius: _isHoveredOrPressed ? 18 : 8,
                  offset: Offset(0, _isHoveredOrPressed ? 6 : 3),
                ),
              ],
            ),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: product.isAvailable ? widget.onSelect : null,
                onHighlightChanged: (val) =>
                    setState(() => _isHoveredOrPressed = val),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabeçalho com título do produto estilo folder ("Pipoca Gourmet ♡")
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: BellaColors.pinkSoft.withValues(alpha: 0.65),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    product.name,
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: BellaColors.darkChocolate,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                AnimatedScale(
                                  scale: _isHoveredOrPressed ? 1.25 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    _isHoveredOrPressed
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 18,
                                    color: _isHoveredOrPressed
                                        ? BellaColors.pinkPrimary
                                        : BellaColors.darkChocolate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!product.isAvailable)
                            const BellaBadge(
                              label: 'Esgotado',
                              backgroundColor: Color(0xFFFFE5E5),
                              textColor: BellaColors.errorRed,
                            )
                          else if (product.isReadyDelivery)
                            const BellaBadge(
                              label: 'Pronta Entrega',
                              icon: Icons.bolt_rounded,
                            ),
                        ],
                      ),
                    ),

                    // Foto Oficial ou Cloudinary do Produto
                    ProductIllustrationBanner(product: product, height: 205),

                    // Corpo: Faixa de Preço em Rosa + Lista de Sabores + Botão
                    Expanded(
                      flex: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Faixa de Preço inspirada na pincelada rosa do folder
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: BellaColors.pinkLight.withValues(
                                  alpha: 0.55,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border:
                                    Border.all(color: BellaColors.pinkBorder),
                              ),
                              child: Text(
                                _buildPriceText(),
                                style: textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: BellaColors.darkChocolate,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Descrição curta do doce
                            Text(
                              product.description,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 14),

                            // Seção "Sabores:" pontilhada como no folder
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: BellaColors.pinkSoft,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: BellaColors.pinkPrimary.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Sabores:',
                                style: textTheme.labelLarge?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: BellaColors.darkChocolate,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Chips de Sabores disponíveis
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: product.flavorNames.map((flavor) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: BellaColors.creamBackground,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: BellaColors.pinkBorder,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.circle,
                                        size: 6,
                                        color: BellaColors.pinkPrimary,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          flavor,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // Botão de ação para abrir seleção de sabores (Módulo 2)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    product.isAvailable ? widget.onSelect : null,
                                icon: const Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 19,
                                ),
                                label: Text(
                                  product.isAvailable
                                      ? 'Escolher Sabor e Adicionar'
                                      : 'Indisponível no momento',
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
            ),
          ),
        ),
      ),
    );
  }
}
