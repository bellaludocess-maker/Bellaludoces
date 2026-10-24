import 'package:flutter/foundation.dart';
import '../../catalog/models/product_model.dart';
import '../../catalog/models/product_option.dart';
import '../models/cart_item_model.dart';

/// Controlador de Estado da Sacola de Compras (Módulo 2).
/// Gerencia adição de itens com sabores/tamanhos, quantidades e cálculo de subtotal.
class CartController extends ChangeNotifier {
  final List<CartItemModel> _items = [];

  List<CartItemModel> get items => List<CartItemModel>.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  /// Quantidade total de unidades na sacola.
  int get totalItemsCount {
    return _items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  /// Subtotal dos itens com precisão de centavos.
  double get subtotal {
    final rawTotal = _items.fold<double>(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
    return double.parse(rawTotal.toStringAsFixed(2));
  }

  /// Adiciona um produto com suas opções escolhidas (sabor/tamanho) e observações.
  /// Se já existir um item idêntico na sacola, soma a quantidade.
  void addItem({
    required ProductModel product,
    required List<ProductOption> selectedOptions,
    int quantity = 1,
    String notes = '',
  }) {
    if (quantity <= 0) return;

    final itemKey = CartItemModel.buildUniqueKey(
      productId: product.id,
      options: selectedOptions,
      notes: notes,
    );

    final existingIndex = _items.indexWhere((item) => item.id == itemKey);

    if (existingIndex >= 0) {
      final current = _items[existingIndex];
      _items[existingIndex] = current.copyWith(
        quantity: current.quantity + quantity,
      );
    } else {
      _items.add(
        CartItemModel(
          id: itemKey,
          product: product,
          selectedOptions: List<ProductOption>.unmodifiable(selectedOptions),
          notes: notes.trim(),
          quantity: quantity,
        ),
      );
    }

    notifyListeners();
  }

  void incrementQuantity(String cartItemId) {
    final index = _items.indexWhere((item) => item.id == cartItemId);
    if (index < 0) return;

    final current = _items[index];
    _items[index] = current.copyWith(quantity: current.quantity + 1);
    notifyListeners();
  }

  void decrementQuantity(String cartItemId) {
    final index = _items.indexWhere((item) => item.id == cartItemId);
    if (index < 0) return;

    final current = _items[index];
    if (current.quantity <= 1) {
      _items.removeAt(index);
    } else {
      _items[index] = current.copyWith(quantity: current.quantity - 1);
    }
    notifyListeners();
  }

  void removeItem(String cartItemId) {
    _items.removeWhere((item) => item.id == cartItemId);
    notifyListeners();
  }

  void clearCart() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
