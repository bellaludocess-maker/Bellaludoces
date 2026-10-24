import '../../../core/utils/currency_formatter.dart';

enum CouponDiscountType {
  percentage('percentage', 'Porcentagem (%)'),
  fixed('fixed', 'Valor Fixo (R\$)'),
  freeShipping('free_shipping', 'Frete Grátis');

  final String key;
  final String label;
  const CouponDiscountType(this.key, this.label);

  static CouponDiscountType fromKey(String key) {
    return CouponDiscountType.values.firstWhere(
      (e) => e.key == key,
      orElse: () => CouponDiscountType.percentage,
    );
  }
}

/// Modelo de Cupom de Desconto / Fidelidade gerenciado pelo Painel Admin.
class CouponModel {
  final String code;
  final CouponDiscountType discountType;
  final double discountValue;
  final double minOrderValue;
  final bool oncePerCustomer;
  final bool isActive;
  final List<String> usedByPhones;

  const CouponModel({
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.minOrderValue = 0.0,
    this.oncePerCustomer = true,
    this.isActive = true,
    this.usedByPhones = const [],
  });

  String get normalizedCode => code.trim().toUpperCase();

  /// Descrição amigável do benefício do cupom.
  String get benefitSummary {
    switch (discountType) {
      case CouponDiscountType.percentage:
        final pct = discountValue == discountValue.roundToDouble()
            ? discountValue.toInt().toString()
            : discountValue.toStringAsFixed(1);
        return '$pct% OFF';
      case CouponDiscountType.fixed:
        return '${CurrencyFormatter.formatBRL(discountValue)} OFF';
      case CouponDiscountType.freeShipping:
        return 'Frete Grátis';
    }
  }

  /// Normaliza o telefone do cliente deixando apenas números para controle de uso único.
  static String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Verifica se o telefone informado já utilizou este cupom.
  bool wasUsedByPhone(String phone) {
    if (!oncePerCustomer) return false;
    final clean = normalizePhone(phone);
    if (clean.length < 8) return false;
    return usedByPhones.any((used) {
      final cleanUsed = normalizePhone(used);
      return cleanUsed == clean ||
          (cleanUsed.length >= 8 &&
              clean.length >= 8 &&
              cleanUsed.substring(cleanUsed.length - 8) ==
                  clean.substring(clean.length - 8));
    });
  }

  /// Valida se o cupom pode ser aplicado ao pedido atual.
  /// Retorna `null` se válido, ou a mensagem de erro caso contrário.
  String? validate({
    required double subtotal,
    String customerPhone = '',
  }) {
    if (!isActive) {
      return 'Este cupom está desativado no momento.';
    }
    if (minOrderValue > 0 && subtotal < minOrderValue) {
      return 'Pedido mínimo de ${CurrencyFormatter.formatBRL(minOrderValue)} para este cupom.';
    }
    if (oncePerCustomer &&
        customerPhone.trim().isNotEmpty &&
        wasUsedByPhone(customerPhone)) {
      return 'Este cupom de uso único já foi utilizado neste telefone.';
    }
    return null;
  }

  /// Calcula o valor em reais (R$) do desconto concedido por este cupom.
  double calculateDiscount({
    required double subtotal,
    required double deliveryFee,
  }) {
    if (!isActive || subtotal < minOrderValue) return 0.0;
    switch (discountType) {
      case CouponDiscountType.percentage:
        final raw = subtotal * (discountValue / 100.0);
        final capped = raw > subtotal ? subtotal : raw;
        return double.parse(capped.toStringAsFixed(2));
      case CouponDiscountType.fixed:
        final capped = discountValue > subtotal ? subtotal : discountValue;
        return double.parse(capped.toStringAsFixed(2));
      case CouponDiscountType.freeShipping:
        return double.parse(deliveryFee.toStringAsFixed(2));
    }
  }

  CouponModel copyWith({
    String? code,
    CouponDiscountType? discountType,
    double? discountValue,
    double? minOrderValue,
    bool? oncePerCustomer,
    bool? isActive,
    List<String>? usedByPhones,
  }) {
    return CouponModel(
      code: code ?? this.code,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      minOrderValue: minOrderValue ?? this.minOrderValue,
      oncePerCustomer: oncePerCustomer ?? this.oncePerCustomer,
      isActive: isActive ?? this.isActive,
      usedByPhones: usedByPhones ?? this.usedByPhones,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': normalizedCode,
      'discountType': discountType.key,
      'discountValue': discountValue,
      'minOrderValue': minOrderValue,
      'oncePerCustomer': oncePerCustomer,
      'isActive': isActive,
      'usedByPhones': usedByPhones,
    };
  }

  factory CouponModel.fromMap(Map<String, dynamic> map) {
    final rawPhones = map['usedByPhones'];
    final phones = rawPhones is List
        ? rawPhones.map((e) => e.toString()).toList()
        : <String>[];
    return CouponModel(
      code: (map['code']?.toString() ?? '').trim().toUpperCase(),
      discountType:
          CouponDiscountType.fromKey(map['discountType']?.toString() ?? ''),
      discountValue: (map['discountValue'] is num)
          ? (map['discountValue'] as num).toDouble()
          : double.tryParse(map['discountValue']?.toString() ?? '') ?? 0.0,
      minOrderValue: (map['minOrderValue'] is num)
          ? (map['minOrderValue'] as num).toDouble()
          : double.tryParse(map['minOrderValue']?.toString() ?? '') ?? 0.0,
      oncePerCustomer: map['oncePerCustomer'] is bool
          ? map['oncePerCustomer'] as bool
          : true,
      isActive: map['isActive'] is bool ? map['isActive'] as bool : true,
      usedByPhones: phones,
    );
  }
}
