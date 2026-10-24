import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/bella_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../controllers/cart_controller.dart';
import '../models/cart_item_model.dart';

/// Gaveta/Modal da Sacola de Compras (Módulo 2).
/// Permite revisar sabores escolhidos, alterar quantidades, remover itens
/// e avançar para o Checkout (Módulo 3).
class CartBottomSheet extends StatelessWidget {
  final CartController controller;
  final VoidCallback? onProceedToCheckout;

  const CartBottomSheet({
    super.key,
    required this.controller,
    this.onProceedToCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: BellaColors.creamBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: BellaColors.pinkLight,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Cabeçalho da Sacola
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag_rounded,
                      color: BellaColors.pinkPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Minha Sacola (${controller.totalItemsCount})',
                        style: textTheme.headlineMedium,
                      ),
                    ),
                    if (items.isNotEmpty)
                      TextButton.icon(
                        key: const ValueKey('clear_cart_button'),
                        onPressed: controller.clearCart,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: BellaColors.errorRed,
                        ),
                        label: const Text(
                          'Limpar',
                          style: TextStyle(color: BellaColors.errorRed),
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(),

              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        size: 56,
                        color: BellaColors.pinkLight,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sua sacola está vazia',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Escolha suas pipocas gourmet ou bolos caseiros na vitrine!',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              else ...[
                // Lista de Itens na Sacola
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _CartItemTile(
                        item: item,
                        onIncrement: () =>
                            controller.incrementQuantity(item.id),
                        onDecrement: () =>
                            controller.decrementQuantity(item.id),
                        onRemove: () => controller.removeItem(item.id),
                      );
                    },
                  ),
                ),

                // Resumo Financeiro e Botão de Checkout
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(
                      top: BorderSide(color: BellaColors.pinkBorder),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: BellaColors.darkChocolate.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal dos doces', style: textTheme.bodyLarge),
                          Text(
                            CurrencyFormatter.formatBRL(controller.subtotal),
                            key: const ValueKey('cart_sheet_subtotal_text'),
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: BellaColors.darkChocolate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.delivery_dining_rounded,
                            size: 16,
                            color: BellaColors.pinkPrimary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Entrega (${CurrencyFormatter.formatBRL(AppConstants.defaultDeliveryFee)}) ou Retirada grátis escolhida na próxima etapa.',
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        key: const ValueKey('proceed_to_checkout_button'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (onProceedToCheckout != null) {
                            onProceedToCheckout!();
                          }
                        },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Continuar para Entrega e Pedido'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItemModel item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BellaColors.pinkBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sabor/Opção: ${item.selectedOptionsSummary}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: BellaColors.pinkDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Obs: "${item.notes}"',
                    style: textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.formatBRL(item.totalPrice),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: BellaColors.darkChocolate,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: BellaColors.pinkSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BellaColors.pinkBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('cart_dec_${item.id}'),
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onDecrement,
                      icon: Icon(
                        item.quantity == 1
                            ? Icons.delete_outline_rounded
                            : Icons.remove_rounded,
                        size: 18,
                        color: item.quantity == 1
                            ? BellaColors.errorRed
                            : BellaColors.darkChocolate,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${item.quantity}',
                        style: textTheme.labelLarge,
                      ),
                    ),
                    IconButton(
                      key: ValueKey('cart_inc_${item.id}'),
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onIncrement,
                      icon: const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: BellaColors.pinkPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
