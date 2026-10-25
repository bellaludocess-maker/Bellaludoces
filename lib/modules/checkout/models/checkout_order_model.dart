import '../../../core/constants/app_constants.dart';
import '../../cart/models/cart_item_model.dart';

/// Modalidade de recebimento do pedido: Entrega ou Retirada.
enum DeliveryMethod {
  delivery,
  pickup;

  String get label {
    switch (this) {
      case DeliveryMethod.delivery:
        return 'Entrega em Domicílio';
      case DeliveryMethod.pickup:
        return 'Retirada (Combinar com a loja)';
    }
  }

  double get fee {
    switch (this) {
      case DeliveryMethod.delivery:
        return AppConstants.defaultDeliveryFee;
      case DeliveryMethod.pickup:
        return AppConstants.pickupFee;
    }
  }
}

/// Formas de pagamento aceitas pela Bella Lu Doces.
enum PaymentMethod {
  pix,
  card,
  cash;

  String get label {
    switch (this) {
      case PaymentMethod.pix:
        return 'Pix';
      case PaymentMethod.card:
        return 'Cartão (Crédito / Débito)';
      case PaymentMethod.cash:
        return 'Dinheiro';
    }
  }
}

/// Modelo imutável com todos os dados consolidados do pedido no Checkout
/// e suporte para persistência automática na coleção `orders` do Firebase.
class CheckoutOrderModel {
  final String id;
  final String createdAt;
  final String customerName;
  final String customerPhone;
  final DeliveryMethod deliveryMethod;
  final String streetAddress;
  final String neighborhood;
  final String referencePoint;
  final String pickupAddress;
  final PaymentMethod paymentMethod;
  final String changeFor;
  final String pixKey;
  final String pixHolderName;
  final String pixBankName;
  final List<CartItemModel> items;
  final List<String> savedItemLines;
  final double? savedSubtotal;
  final double? savedTotal;
  final double? customDeliveryFee;
  final String couponCode;
  final double discountAmount;
  final bool isCompleted;

  const CheckoutOrderModel({
    this.id = '',
    this.createdAt = '',
    required this.customerName,
    required this.customerPhone,
    required this.deliveryMethod,
    this.streetAddress = '',
    this.neighborhood = '',
    this.referencePoint = '',
    this.pickupAddress = '',
    required this.paymentMethod,
    this.changeFor = '',
    this.pixKey = AppConstants.defaultPixKey,
    this.pixHolderName = AppConstants.defaultPixHolderName,
    this.pixBankName = AppConstants.defaultPixBankName,
    this.items = const [],
    this.savedItemLines = const [],
    this.savedSubtotal,
    this.savedTotal,
    this.customDeliveryFee,
    this.couponCode = '',
    this.discountAmount = 0.0,
    this.isCompleted = false,
  });

  double get subtotal {
    if (items.isEmpty && savedSubtotal != null) {
      return savedSubtotal!;
    }
    final raw = items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
    return double.parse(raw.toStringAsFixed(2));
  }

  double get deliveryFee => deliveryMethod == DeliveryMethod.delivery
      ? (customDeliveryFee ?? deliveryMethod.fee)
      : 0.0;

  double get total {
    if (items.isEmpty && savedTotal != null) {
      return savedTotal!;
    }
    final rawTotal = subtotal + deliveryFee - discountAmount;
    final clamped = rawTotal < 0.0 ? 0.0 : rawTotal;
    return double.parse(clamped.toStringAsFixed(2));
  }

  /// Linhas descritivas dos itens do pedido (usadas no painel admin e histórico).
  List<String> get formattedItemLines {
    if (items.isNotEmpty) {
      return items.map((item) {
        final notesPart =
            item.notes.trim().isNotEmpty ? ' [Obs: ${item.notes.trim()}]' : '';
        return '${item.quantity}x ${item.product.name} (${item.selectedOptionsSummary})$notesPart';
      }).toList();
    }
    return savedItemLines;
  }

  CheckoutOrderModel copyWith({
    String? id,
    String? createdAt,
    String? customerName,
    String? customerPhone,
    DeliveryMethod? deliveryMethod,
    String? streetAddress,
    String? neighborhood,
    String? referencePoint,
    String? pickupAddress,
    PaymentMethod? paymentMethod,
    String? changeFor,
    String? pixKey,
    String? pixHolderName,
    String? pixBankName,
    List<CartItemModel>? items,
    List<String>? savedItemLines,
    double? savedSubtotal,
    double? savedTotal,
    double? customDeliveryFee,
    String? couponCode,
    double? discountAmount,
    bool? isCompleted,
  }) {
    return CheckoutOrderModel(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      streetAddress: streetAddress ?? this.streetAddress,
      neighborhood: neighborhood ?? this.neighborhood,
      referencePoint: referencePoint ?? this.referencePoint,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      changeFor: changeFor ?? this.changeFor,
      pixKey: pixKey ?? this.pixKey,
      pixHolderName: pixHolderName ?? this.pixHolderName,
      pixBankName: pixBankName ?? this.pixBankName,
      items: items ?? this.items,
      savedItemLines: savedItemLines ?? this.savedItemLines,
      savedSubtotal: savedSubtotal ?? this.savedSubtotal,
      savedTotal: savedTotal ?? this.savedTotal,
      customDeliveryFee: customDeliveryFee ?? this.customDeliveryFee,
      couponCode: couponCode ?? this.couponCode,
      discountAmount: discountAmount ?? this.discountAmount,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createdAt': createdAt,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryMethod': deliveryMethod.name,
      'streetAddress': streetAddress,
      'neighborhood': neighborhood,
      'referencePoint': referencePoint,
      'pickupAddress': pickupAddress,
      'paymentMethod': paymentMethod.name,
      'changeFor': changeFor,
      'pixKey': pixKey,
      'pixHolderName': pixHolderName,
      'pixBankName': pixBankName,
      'savedItemLines': formattedItemLines,
      'savedSubtotal': subtotal,
      'savedTotal': total,
      'customDeliveryFee': deliveryFee,
      'couponCode': couponCode,
      'discountAmount': discountAmount,
      'isCompleted': isCompleted,
    };
  }

  factory CheckoutOrderModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    final deliveryName = (map['deliveryMethod'] ?? 'delivery').toString();
    final paymentName = (map['paymentMethod'] ?? 'pix').toString();
    final rawLines = (map['savedItemLines'] as List<dynamic>?) ?? const [];

    return CheckoutOrderModel(
      id: (map['id'] as String?)?.isNotEmpty == true
          ? map['id'] as String
          : (docId ?? ''),
      createdAt: (map['createdAt'] ?? '') as String,
      customerName: (map['customerName'] ?? '') as String,
      customerPhone: (map['customerPhone'] ?? '') as String,
      deliveryMethod: DeliveryMethod.values.firstWhere(
        (d) => d.name == deliveryName,
        orElse: () => DeliveryMethod.delivery,
      ),
      streetAddress: (map['streetAddress'] ?? '') as String,
      neighborhood: (map['neighborhood'] ?? '') as String,
      referencePoint: (map['referencePoint'] ?? '') as String,
      pickupAddress: (map['pickupAddress'] ?? '').toString(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (p) => p.name == paymentName,
        orElse: () => PaymentMethod.pix,
      ),
      changeFor: (map['changeFor'] ?? '') as String,
      pixKey: (map['pixKey'] ?? AppConstants.defaultPixKey) as String,
      pixHolderName:
          (map['pixHolderName'] ?? AppConstants.defaultPixHolderName) as String,
      pixBankName:
          (map['pixBankName'] ?? AppConstants.defaultPixBankName) as String,
      savedItemLines: rawLines.map((e) => e.toString()).toList(),
      savedSubtotal: (map['savedSubtotal'] as num?)?.toDouble(),
      savedTotal: (map['savedTotal'] as num?)?.toDouble(),
      customDeliveryFee: (map['customDeliveryFee'] as num?)?.toDouble(),
      couponCode: (map['couponCode'] ?? '').toString(),
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      isCompleted: (map['isCompleted'] as bool?) ?? false,
    );
  }
}
