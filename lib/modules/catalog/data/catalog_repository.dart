import '../../checkout/models/checkout_order_model.dart';
import '../models/category_model.dart';
import '../models/coupon_model.dart';
import '../models/product_model.dart';

/// Contrato abstrato de repositório do catálogo, configurações Pix e pedidos.
/// Permite alternar entre o Mock local (Módulo 1) e o Firestore (Módulo 4)
/// sem alterar uma única linha da interface visual.
abstract class CatalogRepository {
  Future<List<CategoryModel>> getCategories();
  Future<void> saveCategory(CategoryModel category);
  Future<List<ProductModel>> getProducts();
  Stream<List<ProductModel>> watchProducts();
  Future<void> saveProduct(ProductModel product);
  Future<void> deleteProduct(String productId);
  Future<void> toggleProductAvailability(String productId, bool isAvailable);

  /// Configuração dinâmica da Chave Pix da loja.
  Future<Map<String, String>> getPixConfig();
  Future<void> savePixConfig({
    required String pixKey,
    required String pixHolderName,
    required String pixBankName,
  });

  /// Registro e listagem de pedidos recebidos no Painel Admin.
  Future<List<CheckoutOrderModel>> getOrders();
  Future<void> saveOrder(CheckoutOrderModel order);
  Future<void> toggleOrderCompleted(String orderId, bool isCompleted);
  Future<void> deleteOrder(String orderId);
  Future<void> clearCompletedOrders();

  /// Configuração dinâmica do PIN de acesso ao Painel Admin.
  Future<String> getAdminPin();
  Future<void> saveAdminPin(String newPin);

  /// Configuração dinâmica da Taxa de Entrega e Retirada no Local.
  Future<double> getDeliveryFee();
  Future<void> saveDeliveryFee(double fee);
  Future<Map<String, dynamic>> getPickupConfig();
  Future<void> savePickupConfig({
    required bool isPickupEnabled,
    required String pickupAddress,
  });

  /// Gestão de Cupons de Desconto / Fidelidade.
  Future<List<CouponModel>> getCoupons();
  Future<void> saveCoupon(CouponModel coupon);
  Future<void> deleteCoupon(String code);
}
