import 'package:flutter/material.dart';
import '../../../../core/theme/bella_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../controllers/cart_controller.dart';

/// Barra flutuante inferior com animação elástica (Bounce) sempre que
/// novos doces são adicionados à sacola.
class FloatingCartBar extends StatelessWidget {
  final CartController controller;
  final VoidCallback onOpenCart;

  const FloatingCartBar({
    super.key,
    required this.controller,
    required this.onOpenCart,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isEmpty) {
          return const SizedBox.shrink();
        }

        final count = controller.totalItemsCount;
        final itemLabel = count == 1 ? '1 item' : '$count itens';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('cart_bounce_$count'),
                tween: Tween<double>(begin: 0.86, end: 1.0),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Material(
                  color: BellaColors.darkChocolate,
                  borderRadius: BorderRadius.circular(20),
                  elevation: 8,
                  shadowColor: BellaColors.darkChocolate.withValues(alpha: 0.35),
                  child: InkWell(
                    key: const ValueKey('open_cart_bar_button'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: onOpenCart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: BellaColors.pinkPrimary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.shopping_bag_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: Text(
                                    itemLabel,
                                    key: const ValueKey('cart_bar_count_text'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Ver Minha Sacola',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              CurrencyFormatter.formatBRL(controller.subtotal),
                              key: const ValueKey('cart_bar_subtotal_text'),
                              style: const TextStyle(
                                color: BellaColors.pinkLight,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: BellaColors.pinkLight,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
