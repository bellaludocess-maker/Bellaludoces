/// Representa uma opção individual de variação de um produto
/// (ex: Sabor "Oreo", Sabor "Cenoura com Brigadeiro" ou Tamanho "Pacote R$ 25").
class ProductOption {
  final String id;
  final String name;
  final double additionalPrice;
  final bool isAvailable;

  const ProductOption({
    required this.id,
    required this.name,
    this.additionalPrice = 0.0,
    this.isAvailable = true,
  });

  ProductOption copyWith({
    String? id,
    String? name,
    double? additionalPrice,
    bool? isAvailable,
  }) {
    return ProductOption(
      id: id ?? this.id,
      name: name ?? this.name,
      additionalPrice: additionalPrice ?? this.additionalPrice,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'additionalPrice': additionalPrice,
      'isAvailable': isAvailable,
    };
  }

  factory ProductOption.fromMap(Map<String, dynamic> map) {
    return ProductOption(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      additionalPrice: ((map['additionalPrice'] ?? 0.0) as num).toDouble(),
      isAvailable: (map['isAvailable'] ?? true) as bool,
    );
  }
}

/// Agrupador de opções (ex: "Escolha o Sabor", "Escolha o Tamanho")
/// para suportar produtos com múltiplas etapas de escolha no Módulo 2.
class ProductOptionGroup {
  final String id;
  final String title;
  final bool isRequired;
  final List<ProductOption> options;

  const ProductOptionGroup({
    required this.id,
    required this.title,
    this.isRequired = true,
    required this.options,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isRequired': isRequired,
      'options': options.map((o) => o.toMap()).toList(),
    };
  }

  factory ProductOptionGroup.fromMap(Map<String, dynamic> map) {
    final rawOptions = (map['options'] as List<dynamic>?) ?? [];
    return ProductOptionGroup(
      id: (map['id'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      isRequired: (map['isRequired'] ?? true) as bool,
      options: rawOptions
          .map((e) => ProductOption.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
