import 'package:flutter/material.dart';

/// Representa uma categoria do cardápio (ex: Pipocas Gourmet, Bolos Caseiros)
/// utilizando ícones vetoriais nativos em vez de emojis.
class CategoryModel {
  final String id;
  final String name;
  final int sortOrder;

  const CategoryModel({
    required this.id,
    required this.name,
    this.sortOrder = 0,
  });

  /// Retorna o ícone vetorial correspondente à categoria.
  IconData get iconData {
    switch (id) {
      case 'all':
        return Icons.favorite_rounded;
      case 'pipocas':
        return Icons.auto_awesome_rounded;
      case 'bolos':
        return Icons.cake_rounded;
      default:
        return Icons.local_mall_rounded;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sortOrder': sortOrder,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      sortOrder: ((map['sortOrder'] ?? 0) as num).toInt(),
    );
  }
}
