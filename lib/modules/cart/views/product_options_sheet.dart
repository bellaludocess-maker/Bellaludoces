import 'package:flutter/material.dart';
import '../../../core/theme/bella_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/bella_badge.dart';
import '../../catalog/models/product_model.dart';
import '../../catalog/models/product_option.dart';

/// Modal BottomSheet para escolha de sabores, tamanho, quantidade e observações
/// antes de adicionar o doce à sacola.
class ProductOptionsSheet extends StatefulWidget {
  final ProductModel product;
  final void Function({
    required List<ProductOption> selectedOptions,
    required int quantity,
    required String notes,
  }) onAddToCart;

  const ProductOptionsSheet({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<ProductOptionsSheet> createState() => _ProductOptionsSheetState();
}

class _ProductOptionsSheetState extends State<ProductOptionsSheet> {
  late final List<ProductOptionGroup> _effectiveGroups;
  final Map<String, ProductOption> _selectedByGroup = {};
  final TextEditingController _notesController = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    // Se o produto possuir grupos estruturados (ex: Tamanho + Sabor), usa eles.
    // Caso contrário, gera um grupo padrão a partir de `product.options`.
    if (widget.product.optionGroups.isNotEmpty) {
      _effectiveGroups = widget.product.optionGroups;
    } else if (widget.product.options.isNotEmpty) {
      _effectiveGroups = [
        ProductOptionGroup(
          id: 'default-flavors',
          title: 'Escolha o Sabor',
          isRequired: true,
          options: widget.product.options,
        ),
      ];
    } else {
      _effectiveGroups = [];
    }

    // Pré-seleciona a primeira opção disponível de cada grupo obrigatório
    for (final group in _effectiveGroups) {
      final availableOptions =
          group.options.where((o) => o.isAvailable).toList();
      if (group.isRequired && availableOptions.isNotEmpty) {
        _selectedByGroup[group.id] = availableOptions.first;
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _unitPrice {
    final extras = _selectedByGroup.values.fold<double>(
      0.0,
      (sum, option) => sum + option.additionalPrice,
    );
    return double.parse((widget.product.basePrice + extras).toStringAsFixed(2));
  }

  double get _totalPrice {
    return double.parse((_unitPrice * _quantity).toStringAsFixed(2));
  }

  bool get _canSubmit {
    for (final group in _effectiveGroups) {
      if (group.isRequired && !_selectedByGroup.containsKey(group.id)) {
        return false;
      }
    }
    return true;
  }

  void _handleConfirm() {
    if (!_canSubmit) return;

    final orderedSelection = <ProductOption>[];
    for (final group in _effectiveGroups) {
      final selected = _selectedByGroup[group.id];
      if (selected != null) {
        orderedSelection.add(selected);
      }
    }

    widget.onAddToCart(
      selectedOptions: orderedSelection,
      quantity: _quantity,
      notes: _notesController.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: BellaColors.creamBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador superior de arraste
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: BellaColors.pinkLight,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Cabeçalho do Modal
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.product.description,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Fechar',
                ),
              ],
            ),
          ),
          const Divider(),

          // Grupos de Opções (Tamanho / Sabores) + Observação
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in _effectiveGroups) ...[
                    _buildOptionGroupSection(group, textTheme),
                    const SizedBox(height: 18),
                  ],

                  // Campo de Observação
                  Text(
                    'Alguma observação? (Opcional)',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('product_notes_input'),
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText:
                          'Ex: Sem granulado, embalagem para presente, caprichar no brigadeiro...',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // Rodapé Fixo: Seletor de Quantidade + Botão Adicionar com Subtotal
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
            child: Row(
              children: [
                // Controle de Quantidade (- 1 +)
                Container(
                  decoration: BoxDecoration(
                    color: BellaColors.pinkSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BellaColors.pinkBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('decrease_qty_button'),
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        icon: const Icon(Icons.remove_rounded, size: 20),
                        color: BellaColors.darkChocolate,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '$_quantity',
                          key: const ValueKey('sheet_quantity_text'),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('increase_qty_button'),
                        onPressed: () => setState(() => _quantity++),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        color: BellaColors.pinkPrimary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Botão Confirmar Adição
                Expanded(
                  child: ElevatedButton.icon(
                    key: const ValueKey('confirm_add_to_cart_button'),
                    onPressed: _canSubmit ? _handleConfirm : null,
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    label: Text(
                      'Adicionar • ${CurrencyFormatter.formatBRL(_totalPrice)}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionGroupSection(
    ProductOptionGroup group,
    TextTheme textTheme,
  ) {
    final selectedOption = _selectedByGroup[group.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                group.title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (group.isRequired)
              const BellaBadge(
                label: 'Obrigatório',
                backgroundColor: BellaColors.pinkSoft,
                textColor: BellaColors.pinkDark,
              ),
          ],
        ),
        const SizedBox(height: 10),
        ...group.options.map((option) {
          final isSelected = selectedOption?.id == option.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              key: ValueKey('option_${option.id}'),
              borderRadius: BorderRadius.circular(14),
              onTap: option.isAvailable
                  ? () {
                      setState(() {
                        _selectedByGroup[group.id] = option;
                      });
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? BellaColors.pinkSoft : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? BellaColors.pinkPrimary
                        : BellaColors.pinkBorder,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected
                          ? BellaColors.pinkPrimary
                          : BellaColors.softCocoa,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option.name,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (option.additionalPrice > 0)
                      Text(
                        '+ ${CurrencyFormatter.formatBRL(option.additionalPrice)}',
                        style: textTheme.labelLarge?.copyWith(
                          color: BellaColors.pinkDark,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
