import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/data/mock_catalog_repository.dart';
import '../../catalog/models/category_model.dart';
import '../../catalog/models/coupon_model.dart';
import '../../catalog/models/product_model.dart';
import '../../checkout/models/checkout_order_model.dart';
import '../config/cloud_config.dart';

/// Implementação do repositório conectado ao Cloud Firestore (Módulo 4).
/// - Lê e grava na coleção `products` do Firestore.
/// - Possui seed e fallback inteligente com os 3 produtos do folder da Bella Lu
///   para garantir funcionamento imediato tanto em modo offline quanto na nuvem.
class FirestoreCatalogRepository implements CatalogRepository {
  final CloudConfig config;
  final http.Client _httpClient;
  final MockCatalogRepository _seedFallback = MockCatalogRepository();
  final StreamController<List<ProductModel>> _productsStreamController =
      StreamController<List<ProductModel>>.broadcast();

  List<CategoryModel> _cachedCategories = [];
  List<ProductModel> _cachedProducts = [];
  final Set<String> _pendingLocalProductIds = {};
  List<CheckoutOrderModel> _cachedOrders = [];
  String _cachedPixKey = AppConstants.defaultPixKey;
  String _cachedPixHolderName = AppConstants.defaultPixHolderName;
  String _cachedPixBankName = AppConstants.defaultPixBankName;
  String _cachedAdminPin = AppConstants.defaultAdminPin;
  double _cachedDeliveryFee = AppConstants.defaultDeliveryFee;
  List<CouponModel> _cachedCoupons = [];
  bool _initialized = false;
  bool _categoriesInitialized = false;
  bool _couponsInitialized = false;

  FirestoreCatalogRepository({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Uri _buildCollectionUri(String collection) {
    final base =
        'https://firestore.googleapis.com/v1/projects/${config.firebaseProjectId}/databases/(default)/documents/$collection';
    if (config.firebaseApiKey.trim().isNotEmpty) {
      return Uri.parse('$base?key=${config.firebaseApiKey.trim()}');
    }
    return Uri.parse(base);
  }

  Uri _buildDocumentUri(String collection, String docId) {
    final base =
        'https://firestore.googleapis.com/v1/projects/${config.firebaseProjectId}/databases/(default)/documents/$collection/$docId';
    if (config.firebaseApiKey.trim().isNotEmpty) {
      return Uri.parse('$base?key=${config.firebaseApiKey.trim()}');
    }
    return Uri.parse(base);
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    if (!_categoriesInitialized) {
      _cachedCategories = List<CategoryModel>.from(
        await _seedFallback.getCategories(),
      );
      _categoriesInitialized = true;
    }

    if (config.isFirebaseConfigured) {
      try {
        final response = await _httpClient.get(
          _buildCollectionUri(AppConstants.firestoreCategoriesCollection),
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final documents = (decoded['documents'] as List<dynamic>?) ?? [];
          if (documents.isNotEmpty) {
            final remoteCategories = documents.map((doc) {
              final docMap = doc as Map<String, dynamic>;
              final fullName = (docMap['name'] ?? '') as String;
              final docId = fullName.split('/').last;
              final fields =
                  (docMap['fields'] as Map<String, dynamic>?) ?? const {};
              final plainMap = _decodeFirestoreFields(fields);
              plainMap['id'] ??= docId;
              return CategoryModel.fromMap(plainMap);
            }).toList();

            final merged = <String, CategoryModel>{
              for (final c in _cachedCategories) c.id: c,
              for (final c in remoteCategories) c.id: c,
            };
            _cachedCategories = merged.values.toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          }
        }
      } catch (_) {
        // Mantém categorias em cache caso esteja offline
      }
    }

    return List<CategoryModel>.unmodifiable(_cachedCategories);
  }

  @override
  Future<void> saveCategory(CategoryModel category) async {
    if (!_categoriesInitialized) {
      await getCategories();
    }

    final index = _cachedCategories.indexWhere((c) => c.id == category.id);
    if (index >= 0) {
      _cachedCategories[index] = category;
    } else {
      _cachedCategories.add(category);
    }

    if (config.isFirebaseConfigured) {
      try {
        final firestoreDoc = {
          'fields': _encodeFirestoreFields(category.toMap()),
        };
        await _httpClient.patch(
          _buildDocumentUri(
            AppConstants.firestoreCategoriesCollection,
            category.id,
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(firestoreDoc),
        );
      } catch (_) {
        // Mantém salvo na sessão caso esteja offline
      }
    }
  }

  @override
  Future<List<ProductModel>> getProducts() async {
    if (!config.isFirebaseConfigured) {
      if (!_initialized) {
        _cachedProducts = List<ProductModel>.from(
          await _seedFallback.getProducts(),
        );
        _initialized = true;
      }
      return List<ProductModel>.unmodifiable(_cachedProducts);
    }

    try {
      final response = await _httpClient.get(
        _buildCollectionUri(AppConstants.firestoreProductsCollection),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final documents = (decoded['documents'] as List<dynamic>?) ?? [];
        if (documents.isNotEmpty) {
          final remoteProducts = documents.map((doc) {
            final docMap = doc as Map<String, dynamic>;
            final fullName = (docMap['name'] ?? '') as String;
            final docId = fullName.split('/').last;
            final fields =
                (docMap['fields'] as Map<String, dynamic>?) ?? const {};
            final plainMap = _decodeFirestoreFields(fields);
            return ProductModel.fromMap(plainMap, docId: docId);
          }).toList();

          // Prioriza sempre os dados mais recentes do Firebase Firestore,
          // mantendo apenas itens pendentes salvos localmente em modo offline/teste.
          final mergedMap = <String, ProductModel>{
            for (final p in _cachedProducts.where(
              (c) => _pendingLocalProductIds.contains(c.id),
            ))
              p.id: p,
            for (final p in remoteProducts) p.id: p,
          };
          _cachedProducts = mergedMap.values.toList();
          _initialized = true;
          _productsStreamController.add(
            List<ProductModel>.unmodifiable(_cachedProducts),
          );
          return List<ProductModel>.unmodifiable(_cachedProducts);
        }
      }
    } catch (_) {
      // Fallback seguro caso esteja sem internet no momento
    }

    if (!_initialized) {
      _cachedProducts = List<ProductModel>.from(
        await _seedFallback.getProducts(),
      );
      _initialized = true;
    }
    return List<ProductModel>.unmodifiable(_cachedProducts);
  }

  @override
  Stream<List<ProductModel>> watchProducts() async* {
    final initial = await getProducts();
    yield initial;
    yield* _productsStreamController.stream;
  }

  @override
  Future<void> saveProduct(ProductModel product) async {
    if (!_initialized) {
      await getProducts();
    }

    final index = _cachedProducts.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      _cachedProducts[index] = product;
    } else {
      _cachedProducts.add(product);
    }
    _pendingLocalProductIds.add(product.id);

    if (config.isFirebaseConfigured) {
      try {
        final firestoreDoc = {
          'fields': _encodeFirestoreFields(product.toMap()),
        };
        final response = await _httpClient.patch(
          _buildDocumentUri(
            AppConstants.firestoreProductsCollection,
            product.id,
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(firestoreDoc),
        );
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            response.body.contains('"fields"')) {
          _pendingLocalProductIds.remove(product.id);
        }
      } catch (_) {
        // Mantém salvo localmente se a requisição falhar
      }
    }

    _productsStreamController.add(
      List<ProductModel>.unmodifiable(_cachedProducts),
    );
  }

  @override
  Future<void> deleteProduct(String productId) async {
    if (!_initialized) {
      await getProducts();
    }
    _cachedProducts.removeWhere((p) => p.id == productId);
    _pendingLocalProductIds.remove(productId);

    if (config.isFirebaseConfigured) {
      try {
        await _httpClient.delete(
          _buildDocumentUri(
            AppConstants.firestoreProductsCollection,
            productId,
          ),
        );
      } catch (_) {
        // Mantém removido localmente caso esteja offline
      }
    }

    _productsStreamController.add(
      List<ProductModel>.unmodifiable(_cachedProducts),
    );
  }

  @override
  Future<void> toggleProductAvailability(
    String productId,
    bool isAvailable,
  ) async {
    if (!_initialized) {
      await getProducts();
    }

    final index = _cachedProducts.indexWhere((p) => p.id == productId);
    if (index < 0) return;

    final updated = _cachedProducts[index].copyWith(isAvailable: isAvailable);
    await saveProduct(updated);
  }

  @override
  Future<Map<String, String>> getPixConfig() async {
    if (config.isFirebaseConfigured) {
      try {
        final response = await _httpClient.get(
          _buildDocumentUri(
            AppConstants.firestoreSettingsCollection,
            AppConstants.firestorePixConfigDoc,
          ),
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final fields =
              (decoded['fields'] as Map<String, dynamic>?) ?? const {};
          final plainMap = _decodeFirestoreFields(fields);
          final remoteKey = (plainMap['pixKey'] ?? '').toString().trim();
          final remoteHolder =
              (plainMap['pixHolderName'] ?? '').toString().trim();
          final remoteBank =
              (plainMap['pixBankName'] ?? '').toString().trim();
          if (remoteKey.isNotEmpty) {
            _cachedPixKey = remoteKey;
          }
          if (remoteHolder.isNotEmpty) {
            _cachedPixHolderName = remoteHolder;
          }
          if (remoteBank.isNotEmpty) {
            _cachedPixBankName = remoteBank;
          }
        }
      } catch (_) {
        // Mantém chave Pix padrão/cache se estiver offline
      }
    }
    return {
      'pixKey': _cachedPixKey,
      'pixHolderName': _cachedPixHolderName,
      'pixBankName': _cachedPixBankName,
    };
  }

  @override
  Future<void> savePixConfig({
    required String pixKey,
    required String pixHolderName,
    required String pixBankName,
  }) async {
    _cachedPixKey = pixKey.trim().isNotEmpty
        ? pixKey.trim()
        : AppConstants.defaultPixKey;
    _cachedPixHolderName = pixHolderName.trim().isNotEmpty
        ? pixHolderName.trim()
        : AppConstants.defaultPixHolderName;
    _cachedPixBankName = pixBankName.trim().isNotEmpty
        ? pixBankName.trim()
        : AppConstants.defaultPixBankName;

    if (config.isFirebaseConfigured) {
      try {
        final firestoreDoc = {
          'fields': _encodeFirestoreFields({
            'pixKey': _cachedPixKey,
            'pixHolderName': _cachedPixHolderName,
            'pixBankName': _cachedPixBankName,
          }),
        };
        await _httpClient.patch(
          _buildDocumentUri(
            AppConstants.firestoreSettingsCollection,
            AppConstants.firestorePixConfigDoc,
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(firestoreDoc),
        );
      } catch (_) {
        // Mantém em memória se falhar
      }
    }
  }

  @override
  Future<List<CheckoutOrderModel>> getOrders() async {
    if (config.isFirebaseConfigured) {
      try {
        final response = await _httpClient.get(
          _buildCollectionUri(AppConstants.firestoreOrdersCollection),
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final documents = (decoded['documents'] as List<dynamic>?) ?? [];
          if (documents.isNotEmpty) {
            final remoteOrders = documents.map((doc) {
              final docMap = doc as Map<String, dynamic>;
              final fullName = (docMap['name'] ?? '') as String;
              final docId = fullName.split('/').last;
              final fields =
                  (docMap['fields'] as Map<String, dynamic>?) ?? const {};
              final plainMap = _decodeFirestoreFields(fields);
              return CheckoutOrderModel.fromMap(plainMap, docId: docId);
            }).toList();

            final merged = <String, CheckoutOrderModel>{
              for (final o in _cachedOrders) o.id: o,
              for (final o in remoteOrders) o.id: o,
            };
            _cachedOrders = merged.values.toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
        }
      } catch (_) {
        // Mantém pedidos em cache se estiver offline
      }
    }
    return List<CheckoutOrderModel>.unmodifiable(_cachedOrders);
  }

  @override
  Future<void> saveOrder(CheckoutOrderModel order) async {
    final orderId = order.id.trim().isNotEmpty
        ? order.id.trim()
        : 'ped-${DateTime.now().millisecondsSinceEpoch}';
    final createdAt = order.createdAt.trim().isNotEmpty
        ? order.createdAt.trim()
        : DateTime.now().toIso8601String();

    final normalized = order.copyWith(id: orderId, createdAt: createdAt);

    final existingIdx = _cachedOrders.indexWhere((o) => o.id == orderId);
    if (existingIdx >= 0) {
      _cachedOrders[existingIdx] = normalized;
    } else {
      _cachedOrders.insert(0, normalized);
    }

    if (config.isFirebaseConfigured) {
      try {
        final firestoreDoc = {
          'fields': _encodeFirestoreFields(normalized.toMap()),
        };
        await _httpClient.patch(
          _buildDocumentUri(
            AppConstants.firestoreOrdersCollection,
            orderId,
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(firestoreDoc),
        );
      } catch (_) {
        // Mantém salvo localmente se a requisição falhar
      }
    }
  }

  @override
  Future<void> toggleOrderCompleted(String orderId, bool isCompleted) async {
    final idx = _cachedOrders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return;
    final updated = _cachedOrders[idx].copyWith(isCompleted: isCompleted);
    await saveOrder(updated);
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    final cleanId = orderId.trim();
    if (cleanId.isEmpty) return;
    _cachedOrders.removeWhere((o) => o.id == cleanId);

    if (config.isFirebaseConfigured) {
      try {
        await _httpClient.delete(
          _buildDocumentUri(
            AppConstants.firestoreOrdersCollection,
            cleanId,
          ),
        );
      } catch (_) {
        // Mantém removido localmente se estiver offline
      }
    }
  }

  @override
  Future<void> clearCompletedOrders() async {
    final completedIds = _cachedOrders
        .where((o) => o.isCompleted && o.id.trim().isNotEmpty)
        .map((o) => o.id.trim())
        .toList();
    _cachedOrders.removeWhere((o) => o.isCompleted);

    if (config.isFirebaseConfigured) {
      for (final id in completedIds) {
        try {
          await _httpClient.delete(
            _buildDocumentUri(
              AppConstants.firestoreOrdersCollection,
              id,
            ),
          );
        } catch (_) {}
      }
    }
  }

  @override
  Future<String> getAdminPin() async {
    if (config.isFirebaseConfigured) {
      try {
        final response = await _httpClient.get(
          _buildDocumentUri(
            AppConstants.firestoreSettingsCollection,
            AppConstants.firestoreAdminSecurityDoc,
          ),
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final fields =
              (decoded['fields'] as Map<String, dynamic>?) ?? const {};
          final plainMap = _decodeFirestoreFields(fields);
          final remotePin = (plainMap['adminPin'] ?? '').toString().trim();
          if (remotePin.isNotEmpty) {
            _cachedAdminPin = remotePin;
          }
        }
      } catch (_) {
        // Mantém PIN padrão/cache se estiver offline
      }
    }
    return _cachedAdminPin;
  }

  @override
  Future<void> saveAdminPin(String newPin) async {
    final normalized = newPin.trim();
    if (normalized.isEmpty) return;
    _cachedAdminPin = normalized;

    if (config.isFirebaseConfigured) {
      try {
        final firestoreDoc = {
          'fields': _encodeFirestoreFields({'adminPin': _cachedAdminPin}),
        };
        await _httpClient.patch(
          _buildDocumentUri(
            AppConstants.firestoreSettingsCollection,
            AppConstants.firestoreAdminSecurityDoc,
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(firestoreDoc),
        );
      } catch (_) {
        // Mantém em memória se estiver offline
      }
    }
  }

  @override
  Future<double> getDeliveryFee() async {
    if (config.isFirebaseConfigured) {
      try {
        final response = await _httpClient.get(
          _buildDocumentUri(
            AppConstants.firestoreSettingsCollection,
            AppConstants.firestoreDeliveryConfigDoc,
          ),
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final fields =
              (decoded['fields'] as Map<String, dynamic>?) ?? const {};
          final plainMap = _decodeFirestoreFields(fields);
          final rawFee = plainMap['deliveryFee'];
          if (rawFee is num && rawFee >= 0) {
            _cachedDeliveryFee = rawFee.toDouble();
          } else if (rawFee != null) {
            final parsed = double.tryParse(rawFee.toString());
            if (parsed != null && parsed >= 0) {
              _cachedDeliveryFee = parsed;
            }
          }
        }
      } catch (_) {
        // Mantém taxa padrão/cache se estiver offline
      }
    }
    return _cachedDeliveryFee;
  }

  @override
  Future<void> saveDeliveryFee(double fee) async {
    if (fee < 0) return;
    _cachedDeliveryFee = double.parse(fee.toStringAsFixed(2));

    if (config.isFirebaseConfigured) {
      try {
        final firestoreDoc = {
          'fields': _encodeFirestoreFields({
            'deliveryFee': _cachedDeliveryFee,
          }),
        };
        await _httpClient.patch(
          _buildDocumentUri(
            AppConstants.firestoreSettingsCollection,
            AppConstants.firestoreDeliveryConfigDoc,
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(firestoreDoc),
        );
      } catch (_) {
        // Mantém em memória se estiver offline
      }
    }
  }

  @override
  Future<List<CouponModel>> getCoupons() async {
    if (!_couponsInitialized) {
      _cachedCoupons = List<CouponModel>.from(await _seedFallback.getCoupons());
      _couponsInitialized = true;
    }

    if (config.isFirebaseConfigured) {
      try {
        final response = await _httpClient.get(
          _buildCollectionUri(AppConstants.firestoreCouponsCollection),
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final docs = (decoded['documents'] as List<dynamic>?) ?? [];
          if (docs.isNotEmpty) {
            final remoteCoupons = <CouponModel>[];
            for (final doc in docs) {
              final docMap = doc as Map<String, dynamic>;
              final fields =
                  (docMap['fields'] as Map<String, dynamic>?) ?? const {};
              final plainMap = _decodeFirestoreFields(fields);
              if (plainMap['code'] != null &&
                  plainMap['code'].toString().trim().isNotEmpty) {
                remoteCoupons.add(CouponModel.fromMap(plainMap));
              }
            }
            if (remoteCoupons.isNotEmpty) {
              _cachedCoupons = remoteCoupons;
            }
          }
        }
      } catch (_) {
        // Mantém cache local se estiver offline
      }
    }
    return List<CouponModel>.unmodifiable(_cachedCoupons);
  }

  @override
  Future<void> saveCoupon(CouponModel coupon) async {
    if (!_couponsInitialized) {
      await getCoupons();
    }
    final normalized = coupon.copyWith(code: coupon.normalizedCode);
    final idx = _cachedCoupons
        .indexWhere((c) => c.normalizedCode == normalized.normalizedCode);
    if (idx >= 0) {
      _cachedCoupons[idx] = normalized;
    } else {
      _cachedCoupons.add(normalized);
    }

    if (config.isFirebaseConfigured) {
      try {
        final firestoreDoc = {
          'fields': _encodeFirestoreFields(normalized.toMap()),
        };
        await _httpClient.patch(
          _buildDocumentUri(
            AppConstants.firestoreCouponsCollection,
            normalized.normalizedCode,
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(firestoreDoc),
        );
      } catch (_) {
        // Mantém em memória se estiver offline
      }
    }
  }

  @override
  Future<void> deleteCoupon(String code) async {
    if (!_couponsInitialized) {
      await getCoupons();
    }
    final cleanCode = code.trim().toUpperCase();
    _cachedCoupons.removeWhere((c) => c.normalizedCode == cleanCode);

    if (config.isFirebaseConfigured) {
      try {
        await _httpClient.delete(
          _buildDocumentUri(
            AppConstants.firestoreCouponsCollection,
            cleanCode,
          ),
        );
      } catch (_) {
        // Mantém removido localmente se estiver offline
      }
    }
  }

  /// Converte um Map Dart comum para o formato de `fields` da API do Firestore.
  static Map<String, dynamic> _encodeFirestoreFields(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value != null) {
        result[key] = _encodeValue(value);
      }
    });
    return result;
  }

  static Map<String, dynamic> _encodeValue(dynamic value) {
    if (value is String) {
      return {'stringValue': value};
    } else if (value is bool) {
      return {'booleanValue': value};
    } else if (value is int) {
      return {'integerValue': value.toString()};
    } else if (value is double) {
      return {'doubleValue': value};
    } else if (value is List) {
      return {
        'arrayValue': {
          'values': value.map(_encodeValue).toList(),
        },
      };
    } else if (value is Map<String, dynamic>) {
      return {
        'mapValue': {
          'fields': _encodeFirestoreFields(value),
        },
      };
    }
    return {'stringValue': value.toString()};
  }

  /// Decodifica o formato `fields` do Firestore de volta para um Map Dart comum.
  static Map<String, dynamic> _decodeFirestoreFields(
    Map<String, dynamic> fields,
  ) {
    final result = <String, dynamic>{};
    fields.forEach((key, rawWrapper) {
      if (rawWrapper is Map<String, dynamic>) {
        result[key] = _decodeValue(rawWrapper);
      }
    });
    return result;
  }

  static dynamic _decodeValue(Map<String, dynamic> wrapper) {
    if (wrapper.containsKey('stringValue')) {
      return wrapper['stringValue'] as String;
    } else if (wrapper.containsKey('booleanValue')) {
      return wrapper['booleanValue'] as bool;
    } else if (wrapper.containsKey('integerValue')) {
      return int.tryParse(wrapper['integerValue'].toString()) ?? 0;
    } else if (wrapper.containsKey('doubleValue')) {
      return (wrapper['doubleValue'] as num).toDouble();
    } else if (wrapper.containsKey('arrayValue')) {
      final arrayMap = wrapper['arrayValue'] as Map<String, dynamic>;
      final values = (arrayMap['values'] as List<dynamic>?) ?? [];
      return values
          .map((v) => _decodeValue(Map<String, dynamic>.from(v as Map)))
          .toList();
    } else if (wrapper.containsKey('mapValue')) {
      final mapVal = wrapper['mapValue'] as Map<String, dynamic>;
      final innerFields =
          (mapVal['fields'] as Map<String, dynamic>?) ?? const {};
      return _decodeFirestoreFields(innerFields);
    }
    return null;
  }
}
