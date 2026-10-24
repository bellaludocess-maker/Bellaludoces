import '../../catalog/models/product_model.dart';
import '../../catalog/models/product_option.dart';

/// Representa um item adicionado à sacola de compras com suas variações
/// escolhidas (tamanho, sabor), observações e quantidade.
class CartItemModel {
  final String id;
  final ProductModel product;
  final List<ProductOption> selectedOptions;
  final String notes;
  final int quantity;

  const CartItemModel({
    required this.id,
    required this.product,
    required this.selectedOptions,
    this.notes = '',
    this.quantity = 1,
  });

  /// Gera uma chave única combinando produto, opções selecionadas e observação.
  static String buildUniqueKey({
    required String productId,
    required List<ProductOption> options,
    required String notes,
  }) {
    final optionIds = options.map((o) => o.id).toList()..sort();
    final normalizedNotes = notes.trim().toLowerCase();
    return '$productId::${optionIds.join("|")}::$normalizedNotes';
  }

  /// Preço unitário final considerando o preço base + adicionais (ex: pacote de R$ 25).
  double get unitPrice {
    final extras = selectedOptions.fold<double>(
      0.0,
      (sum, option) => sum + option.additionalPrice,
    );
    return double.parse((product.basePrice + extras).toStringAsFixed(2));
  }

  /// Preço total da linha (unitário * quantidade) com precisão de centavos.
  double get totalPrice {
    return double.parse((unitPrice * quantity).toStringAsFixed(2));
  }

  /// Texto resumido das opções escolhidas (ex: "Pacote Tradicional • Oreo").
  String get selectedOptionsSummary {
    if (selectedOptions.isEmpty) return 'Padrão';
    return selectedOptions.map((o) => o.name).join(' • ');
  }

  CartItemModel copyWith({
    String? id,
    ProductModel? product,
    List<ProductOption>? selectedOptions,
    String? notes,
    int? quantity,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      product: product ?? this.product,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      notes: notes ?? this.notes,
      quantity: quantity ?? this.quantity,
    );
  }
}
