import 'dart:async';
import '../../../core/constants/app_constants.dart';
import '../../checkout/models/checkout_order_model.dart';
import '../models/category_model.dart';
import '../models/coupon_model.dart';
import '../models/product_model.dart';
import '../models/product_option.dart';
import 'catalog_repository.dart';

/// Implementação inicial com os dados fiéis do folder da Bella Lu Doces.
class MockCatalogRepository implements CatalogRepository {
  final StreamController<List<ProductModel>> _productsStreamController =
      StreamController<List<ProductModel>>.broadcast();

  late final List<CategoryModel> _categories = [
    const CategoryModel(
      id: 'all',
      name: 'Todos',
      sortOrder: 0,
    ),
    const CategoryModel(
      id: 'pipocas',
      name: 'Pipocas Gourmet',
      sortOrder: 1,
    ),
    const CategoryModel(
      id: 'bolos',
      name: 'Bolos Caseiros',
      sortOrder: 2,
    ),
  ];

  late final List<ProductModel> _products = [
    const ProductModel(
      id: 'pipoca-gourmet',
      name: 'Pipoca Gourmet',
      description:
          'Pipoca artesanal super crocante banhada em chocolate nobre, embalada em pacote kraft selado para manter a crocância.',
      imageUrl: 'assets/images/pipoca_gourmet.jpg',
      basePrice: 20.00,
      secondaryPrice: 25.00,
      categoryId: 'pipocas',
      categoryName: 'Pipocas Gourmet',
      isAvailable: true,
      isReadyDelivery: true,
      options: [
        ProductOption(id: 'sabor-oreo', name: 'Oreo', additionalPrice: 0.0),
        ProductOption(id: 'sabor-ninho', name: 'Ninho', additionalPrice: 0.0),
      ],
      optionGroups: [
        ProductOptionGroup(
          id: 'group-tamanho-pipoca',
          title: 'Escolha a Opção / Tamanho',
          isRequired: true,
          options: [
            ProductOption(
              id: 'tam-20',
              name: 'Pacote Tradicional (R\$ 20,00)',
              additionalPrice: 0.0,
            ),
            ProductOption(
              id: 'tam-25',
              name: 'Pacote Especial (R\$ 25,00)',
              additionalPrice: 5.0,
            ),
          ],
        ),
        ProductOptionGroup(
          id: 'group-sabor-pipoca',
          title: 'Escolha o Sabor',
          isRequired: true,
          options: [
            ProductOption(id: 'sabor-oreo', name: 'Oreo', additionalPrice: 0.0),
            ProductOption(
              id: 'sabor-ninho',
              name: 'Ninho',
              additionalPrice: 0.0,
            ),
          ],
        ),
      ],
    ),
    const ProductModel(
      id: 'pipoca-gourmet-creme',
      name: 'Pipoca Gourmet com Creme',
      description:
          'Pote recheado com camadas generosas de creme artesanal e pipoca gourmet super crocante. Uma explosão de sabor!',
      imageUrl: 'assets/images/pipoca_creme.jpg',
      basePrice: 35.00,
      categoryId: 'pipocas',
      categoryName: 'Pipocas Gourmet',
      isAvailable: true,
      isReadyDelivery: true,
      options: [
        ProductOption(
          id: 'creme-ninho',
          name: 'Ninho',
          additionalPrice: 0.0,
        ),
        ProductOption(
          id: 'creme-ninho-nutella',
          name: 'Ninho com Nutella',
          additionalPrice: 0.0,
        ),
      ],
      optionGroups: [
        ProductOptionGroup(
          id: 'group-sabor-pipoca-creme',
          title: 'Escolha o Sabor',
          isRequired: true,
          options: [
            ProductOption(
              id: 'creme-ninho',
              name: 'Ninho',
              additionalPrice: 0.0,
            ),
            ProductOption(
              id: 'creme-ninho-nutella',
              name: 'Ninho com Nutella',
              additionalPrice: 0.0,
            ),
          ],
        ),
      ],
    ),
    const ProductModel(
      id: 'bolo-caseiro',
      name: 'Bolo Caseiro',
      description:
          'Bolo caseiro fofinho feito com ingredientes selecionados e cobertura super cremosa de brigadeiro ou Ninho.',
      imageUrl: 'assets/images/bolo_caseiro.jpg',
      basePrice: 15.00,
      categoryId: 'bolos',
      categoryName: 'Bolos Caseiros',
      isAvailable: true,
      isReadyDelivery: true,
      options: [
        ProductOption(
          id: 'bolo-cenoura-brigadeiro',
          name: 'Cenoura com Brigadeiro',
          additionalPrice: 0.0,
        ),
        ProductOption(
          id: 'bolo-choc-brigadeiro',
          name: 'Chocolate com Brigadeiro',
          additionalPrice: 0.0,
        ),
        ProductOption(
          id: 'bolo-choc-ninho',
          name: 'Chocolate com Ninho',
          additionalPrice: 0.0,
        ),
      ],
      optionGroups: [
        ProductOptionGroup(
          id: 'group-sabor-bolo',
          title: 'Escolha o Sabor',
          isRequired: true,
          options: [
            ProductOption(
              id: 'bolo-cenoura-brigadeiro',
              name: 'Cenoura com Brigadeiro',
              additionalPrice: 0.0,
            ),
            ProductOption(
              id: 'bolo-choc-brigadeiro',
              name: 'Chocolate com Brigadeiro',
              additionalPrice: 0.0,
            ),
            ProductOption(
              id: 'bolo-choc-ninho',
              name: 'Chocolate com Ninho',
              additionalPrice: 0.0,
            ),
          ],
        ),
      ],
    ),
  ];

  String _pixKey = AppConstants.defaultPixKey;
  String _pixHolderName = AppConstants.defaultPixHolderName;
  String _pixBankName = AppConstants.defaultPixBankName;
  String _adminPin = AppConstants.defaultAdminPin;
  double _deliveryFee = AppConstants.defaultDeliveryFee;
  final List<CheckoutOrderModel> _orders = [];
  final List<CouponModel> _coupons = [
    const CouponModel(
      code: 'VOLTE10',
      discountType: CouponDiscountType.percentage,
      discountValue: 10.0,
      minOrderValue: 0.0,
      oncePerCustomer: true,
      isActive: true,
    ),
  ];

  @override
  Future<List<CategoryModel>> getCategories() async {
    return List<CategoryModel>.unmodifiable(_categories);
  }

  @override
  Future<void> saveCategory(CategoryModel category) async {
    final existingIndex = _categories.indexWhere((c) => c.id == category.id);
    if (existingIndex >= 0) {
      _categories[existingIndex] = category;
    } else {
      _categories.add(category);
    }
  }

  @override
  Future<List<ProductModel>> getProducts() async {
    return List<ProductModel>.unmodifiable(_products);
  }

  @override
  Stream<List<ProductModel>> watchProducts() async* {
    yield List<ProductModel>.unmodifiable(_products);
    yield* _productsStreamController.stream;
  }

  @override
  Future<void> saveProduct(ProductModel product) async {
    final existingIndex = _products.indexWhere((p) => p.id == product.id);
    if (existingIndex >= 0) {
      _products[existingIndex] = product;
    } else {
      _products.add(product);
    }
    _productsStreamController.add(List<ProductModel>.unmodifiable(_products));
  }

  @override
  Future<void> deleteProduct(String productId) async {
    _products.removeWhere((p) => p.id == productId);
    _productsStreamController.add(List<ProductModel>.unmodifiable(_products));
  }

  @override
  Future<void> toggleProductAvailability(
      String productId, bool isAvailable) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index >= 0) {
      _products[index] = _products[index].copyWith(isAvailable: isAvailable);
      _productsStreamController.add(List<ProductModel>.unmodifiable(_products));
    }
  }

  @override
  Future<Map<String, String>> getPixConfig() async {
    return {
      'pixKey': _pixKey,
      'pixHolderName': _pixHolderName,
      'pixBankName': _pixBankName,
    };
  }

  @override
  Future<void> savePixConfig({
    required String pixKey,
    required String pixHolderName,
    required String pixBankName,
  }) async {
    _pixKey = pixKey.trim();
    _pixHolderName = pixHolderName.trim();
    _pixBankName = pixBankName.trim();
  }

  @override
  Future<List<CheckoutOrderModel>> getOrders() async {
    return List<CheckoutOrderModel>.unmodifiable(_orders);
  }

  @override
  Future<void> saveOrder(CheckoutOrderModel order) async {
    final existingIndex = _orders.indexWhere((o) => o.id == order.id);
    if (existingIndex >= 0) {
      _orders[existingIndex] = order;
    } else {
      _orders.insert(0, order);
    }
  }

  @override
  Future<void> toggleOrderCompleted(String orderId, bool isCompleted) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _orders[index] = _orders[index].copyWith(isCompleted: isCompleted);
    }
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    _orders.removeWhere((o) => o.id == orderId);
  }

  @override
  Future<void> clearCompletedOrders() async {
    _orders.removeWhere((o) => o.isCompleted);
  }

  @override
  Future<String> getAdminPin() async {
    return _adminPin;
  }

  @override
  Future<void> saveAdminPin(String newPin) async {
    if (newPin.trim().isNotEmpty) {
      _adminPin = newPin.trim();
    }
  }

  @override
  Future<double> getDeliveryFee() async {
    return _deliveryFee;
  }

  @override
  Future<void> saveDeliveryFee(double fee) async {
    if (fee >= 0) {
      _deliveryFee = fee;
    }
  }

  @override
  Future<List<CouponModel>> getCoupons() async {
    return List<CouponModel>.unmodifiable(_coupons);
  }

  @override
  Future<void> saveCoupon(CouponModel coupon) async {
    final code = coupon.normalizedCode;
    final idx = _coupons.indexWhere((c) => c.normalizedCode == code);
    if (idx >= 0) {
      _coupons[idx] = coupon.copyWith(code: code);
    } else {
      _coupons.add(coupon.copyWith(code: code));
    }
  }

  @override
  Future<void> deleteCoupon(String code) async {
    final cleanCode = code.trim().toUpperCase();
    _coupons.removeWhere((c) => c.normalizedCode == cleanCode);
  }
}
