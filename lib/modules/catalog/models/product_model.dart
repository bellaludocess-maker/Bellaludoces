import 'product_option.dart';

/// Modelo principal de Produto da Bella Lu Doces.
/// Contrato estável preparado desde o Módulo 1 para suportar:
/// - Sabores e tamanhos (Módulo 2)
/// - Serialização Firestore e URLs Cloudinary (Módulo 4)
/// - Gestão e cadastro administrativo (Módulo 5)
class ProductModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double basePrice;
  final double? secondaryPrice;
  final String categoryId;
  final String categoryName;
  final List<ProductOption> options;
  final List<ProductOptionGroup> optionGroups;
  final bool isAvailable;
  final bool isPromotion;
  final bool isReadyDelivery;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.basePrice,
    this.secondaryPrice,
    required this.categoryId,
    required this.categoryName,
    required this.options,
    this.optionGroups = const [],
    this.isAvailable = true,
    this.isPromotion = false,
    this.isReadyDelivery = true,
  });

  /// Lista rápida com os nomes dos sabores principais para exibição nos cards.
  List<String> get flavorNames => options.map((o) => o.name).toList();

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    double? basePrice,
    double? secondaryPrice,
    String? categoryId,
    String? categoryName,
    List<ProductOption>? options,
    List<ProductOptionGroup>? optionGroups,
    bool? isAvailable,
    bool? isPromotion,
    bool? isReadyDelivery,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      basePrice: basePrice ?? this.basePrice,
      secondaryPrice: secondaryPrice ?? this.secondaryPrice,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      options: options ?? this.options,
      optionGroups: optionGroups ?? this.optionGroups,
      isAvailable: isAvailable ?? this.isAvailable,
      isPromotion: isPromotion ?? this.isPromotion,
      isReadyDelivery: isReadyDelivery ?? this.isReadyDelivery,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'basePrice': basePrice,
      'secondaryPrice': secondaryPrice,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'options': options.map((o) => o.toMap()).toList(),
      'optionGroups': optionGroups.map((g) => g.toMap()).toList(),
      'isAvailable': isAvailable,
      'isPromotion': isPromotion,
      'isReadyDelivery': isReadyDelivery,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawOptions = (map['options'] as List<dynamic>?) ?? [];
    final rawGroups = (map['optionGroups'] as List<dynamic>?) ?? [];

    return ProductModel(
      id: docId ?? (map['id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      imageUrl: (map['imageUrl'] ?? '') as String,
      basePrice: ((map['basePrice'] ?? 0.0) as num).toDouble(),
      secondaryPrice: map['secondaryPrice'] != null
          ? (map['secondaryPrice'] as num).toDouble()
          : null,
      categoryId: (map['categoryId'] ?? '') as String,
      categoryName: (map['categoryName'] ?? '') as String,
      options: rawOptions
          .map((e) => ProductOption.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      optionGroups: rawGroups
          .map((e) =>
              ProductOptionGroup.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      isAvailable: (map['isAvailable'] ?? true) as bool,
      isPromotion: (map['isPromotion'] ?? false) as bool,
      isReadyDelivery: (map['isReadyDelivery'] ?? true) as bool,
    );
  }
}
