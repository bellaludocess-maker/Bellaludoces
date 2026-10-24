import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../checkout/models/checkout_order_model.dart';
import '../data/catalog_repository.dart';
import '../models/category_model.dart';
import '../models/coupon_model.dart';
import '../models/product_model.dart';

/// Gerenciador de estado da Vitrine e Catálogo de Produtos.
/// Escuta o stream `watchProducts()` para refletir atualizações do Firestore em tempo real.
class CatalogController extends ChangeNotifier {
  final CatalogRepository repository;
  StreamSubscription<List<ProductModel>>? _productsSub;

  List<CategoryModel> _categories = [];
  List<ProductModel> _allProducts = [];
  List<CheckoutOrderModel> _orders = [];
  List<CouponModel> _coupons = [];
  String _pixKey = AppConstants.defaultPixKey;
  String _pixHolderName = AppConstants.defaultPixHolderName;
  String _pixBankName = AppConstants.defaultPixBankName;
  String _adminPin = AppConstants.defaultAdminPin;
  double _deliveryFee = AppConstants.defaultDeliveryFee;
  String _selectedCategoryId = 'all';
  String _searchQuery = '';
  bool _isLoading = false;

  CatalogController({required this.repository}) {
    loadCatalog();
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    super.dispose();
  }

  List<CategoryModel> get categories => _categories;
  List<ProductModel> get allProducts => _allProducts;
  List<CheckoutOrderModel> get orders => _orders;
  List<CouponModel> get coupons => _coupons;
  String get pixKey => _pixKey;
  String get pixHolderName => _pixHolderName;
  String get pixBankName => _pixBankName;
  String get adminPin => _adminPin;
  double get deliveryFee => _deliveryFee;
  String get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  /// Retorna os produtos filtrados pela categoria selecionada e termo de busca.
  List<ProductModel> get filteredProducts {
    return _allProducts.where((product) {
      final matchesCategory = _selectedCategoryId == 'all' ||
          product.categoryId == _selectedCategoryId;

      if (!matchesCategory) return false;

      if (_searchQuery.trim().isEmpty) return true;

      final q = _searchQuery.toLowerCase();
      final matchesName = product.name.toLowerCase().contains(q);
      final matchesFlavor =
          product.flavorNames.any((f) => f.toLowerCase().contains(q));
      return matchesName || matchesFlavor;
    }).toList();
  }

  Future<void> loadCatalog() async {
    _isLoading = true;
    notifyListeners();

    _categories = await repository.getCategories();
    _allProducts = await repository.getProducts();
    final pixMap = await repository.getPixConfig();
    _pixKey = pixMap['pixKey'] ?? AppConstants.defaultPixKey;
    _pixHolderName =
        pixMap['pixHolderName'] ?? AppConstants.defaultPixHolderName;
    _pixBankName = pixMap['pixBankName'] ?? AppConstants.defaultPixBankName;
    _adminPin = await repository.getAdminPin();
    _deliveryFee = await repository.getDeliveryFee();
    _coupons = await repository.getCoupons();
    _orders = await repository.getOrders();

    await _productsSub?.cancel();
    _productsSub = repository.watchProducts().listen((updatedProducts) {
      _allProducts = updatedProducts;
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();
  }

  void selectCategory(String categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> saveProduct(ProductModel product) async {
    await repository.saveProduct(product);
    _allProducts = await repository.getProducts();
    notifyListeners();
  }

  Future<void> deleteProduct(String productId) async {
    await repository.deleteProduct(productId);
    _allProducts = await repository.getProducts();
    notifyListeners();
  }

  Future<void> saveCategory(CategoryModel category) async {
    await repository.saveCategory(category);
    _categories = await repository.getCategories();
    notifyListeners();
  }

  Future<void> toggleAvailability(String productId, bool isAvailable) async {
    await repository.toggleProductAvailability(productId, isAvailable);
    _allProducts = await repository.getProducts();
    notifyListeners();
  }

  Future<void> savePixConfig({
    required String pixKey,
    required String pixHolderName,
    required String pixBankName,
  }) async {
    await repository.savePixConfig(
      pixKey: pixKey,
      pixHolderName: pixHolderName,
      pixBankName: pixBankName,
    );
    final pixMap = await repository.getPixConfig();
    _pixKey = pixMap['pixKey'] ?? AppConstants.defaultPixKey;
    _pixHolderName =
        pixMap['pixHolderName'] ?? AppConstants.defaultPixHolderName;
    _pixBankName = pixMap['pixBankName'] ?? AppConstants.defaultPixBankName;
    notifyListeners();
  }

  Future<void> saveOrder(CheckoutOrderModel order) async {
    await repository.saveOrder(order);
    if (order.couponCode.trim().isNotEmpty &&
        order.customerPhone.trim().isNotEmpty) {
      final matched = findCouponByCode(order.couponCode);
      if (matched != null && matched.oncePerCustomer) {
        final cleanPhone = CouponModel.normalizePhone(order.customerPhone);
        if (cleanPhone.isNotEmpty &&
            !matched.usedByPhones.contains(cleanPhone)) {
          final updatedCoupon = matched.copyWith(
            usedByPhones: [...matched.usedByPhones, cleanPhone],
          );
          await repository.saveCoupon(updatedCoupon);
          _coupons = await repository.getCoupons();
        }
      }
    }
    _orders = await repository.getOrders();
    notifyListeners();
  }

  Future<void> toggleOrderCompleted(String orderId, bool isCompleted) async {
    await repository.toggleOrderCompleted(orderId, isCompleted);
    _orders = await repository.getOrders();
    notifyListeners();
  }

  Future<void> deleteOrder(String orderId) async {
    await repository.deleteOrder(orderId);
    _orders = await repository.getOrders();
    notifyListeners();
  }

  Future<void> clearCompletedOrders() async {
    await repository.clearCompletedOrders();
    _orders = await repository.getOrders();
    notifyListeners();
  }

  Future<void> refreshOrders() async {
    _orders = await repository.getOrders();
    notifyListeners();
  }

  Future<void> saveAdminPin(String newPin) async {
    await repository.saveAdminPin(newPin);
    _adminPin = await repository.getAdminPin();
    notifyListeners();
  }

  Future<void> saveDeliveryFee(double fee) async {
    await repository.saveDeliveryFee(fee);
    _deliveryFee = await repository.getDeliveryFee();
    notifyListeners();
  }

  CouponModel? findCouponByCode(String code) {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return null;
    for (final c in _coupons) {
      if (c.normalizedCode == clean) return c;
    }
    return null;
  }

  Future<void> saveCoupon(CouponModel coupon) async {
    await repository.saveCoupon(coupon);
    _coupons = await repository.getCoupons();
    notifyListeners();
  }

  Future<void> deleteCoupon(String code) async {
    await repository.deleteCoupon(code);
    _coupons = await repository.getCoupons();
    notifyListeners();
  }

  Future<void> toggleCouponActive(String code, bool isActive) async {
    final existing = findCouponByCode(code);
    if (existing == null) return;
    await repository.saveCoupon(existing.copyWith(isActive: isActive));
    _coupons = await repository.getCoupons();
    notifyListeners();
  }
}
