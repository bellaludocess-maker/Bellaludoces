import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../models/checkout_order_model.dart';

/// Serviço de integração com o Checkout Integrado da InfinitePay (`$lucineide-silva-jan`).
/// Gera links dinâmicos para pagamento via Pix (taxa R$ 0,00) ou Cartão de Crédito
/// com retorno automático (`redirect_url`) e rastreio por `order_nsu`.
class InfinitePayCheckoutService {
  final http.Client _httpClient;
  final Future<bool> Function(Uri uri)? customLauncher;

  InfinitePayCheckoutService({
    http.Client? httpClient,
    this.customLauncher,
  }) : _httpClient = httpClient ?? http.Client();

  /// Monta a lista de itens em centavos no padrão da InfinitePay.
  List<Map<String, dynamic>> buildItemsPayload(CheckoutOrderModel order) {
    if (order.discountAmount > 0) {
      final totalInCents = (order.total * 100).round();
      final summaryParts = order.formattedItemLines.join(' + ');
      final couponPart = order.couponCode.trim().isNotEmpty
          ? ' [Cupom ${order.couponCode.trim().toUpperCase()}]'
          : ' [Com Desconto]';
      final desc = summaryParts.isNotEmpty
          ? '$summaryParts$couponPart'
          : 'Pedido ${AppConstants.storeName}$couponPart';
      return [
        {
          'quantity': 1,
          'price': totalInCents > 0 ? totalInCents : 100,
          'description': desc,
          'name': desc,
        },
      ];
    }

    final items = <Map<String, dynamic>>[];

    for (final item in order.items) {
      final priceInCents = (item.unitPrice * 100).round();
      final desc = '${item.product.name} (${item.selectedOptionsSummary})';
      items.add({
        'quantity': item.quantity,
        'price': priceInCents,
        'description': desc,
        'name': desc,
      });
    }

    if (order.deliveryMethod == DeliveryMethod.delivery &&
        order.deliveryFee > 0) {
      final feeInCents = (order.deliveryFee * 100).round();
      items.add({
        'quantity': 1,
        'price': feeInCents,
        'description': 'Taxa de Entrega',
        'name': 'Taxa de Entrega',
      });
    }

    if (items.isEmpty) {
      final totalInCents = (order.total * 100).round();
      items.add({
        'quantity': 1,
        'price': totalInCents > 0 ? totalInCents : 100,
        'description': 'Pedido ${AppConstants.storeName}',
        'name': 'Pedido ${AppConstants.storeName}',
      });
    }

    return items;
  }

  /// Constrói a URL direta de Checkout Integrado da InfinitePay (fallback universal livre de CORS).
  Uri buildDirectCheckoutUri(CheckoutOrderModel order) {
    final handle = AppConstants.infinitePayHandle.trim();
    final orderNsu = order.id.trim().isNotEmpty
        ? order.id.trim()
        : 'ped-${DateTime.now().millisecondsSinceEpoch}';
    final items = buildItemsPayload(order);
    final digitsPhone = order.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final formattedPhone = digitsPhone.startsWith('55')
        ? '+$digitsPhone'
        : '+55$digitsPhone';

    final queryParams = <String, String>{
      'items': jsonEncode(items),
      'order_nsu': orderNsu,
      'redirect_url': AppConstants.infinitePayRedirectUrl,
      if (order.customerName.trim().isNotEmpty)
        'customer_name': order.customerName.trim(),
      if (digitsPhone.isNotEmpty) 'customer_cellphone': formattedPhone,
    };

    return Uri.https('checkout.infinitepay.io', '/$handle', queryParams);
  }

  /// Solicita a URL de checkout via API da InfinitePay ou retorna a URL direta integrada.
  Future<Uri> createCheckoutUri(CheckoutOrderModel order) async {
    final handle = AppConstants.infinitePayHandle.trim();
    final orderNsu = order.id.trim().isNotEmpty
        ? order.id.trim()
        : 'ped-${DateTime.now().millisecondsSinceEpoch}';
    final items = buildItemsPayload(order);
    final digitsPhone = order.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final formattedPhone = digitsPhone.startsWith('55')
        ? '+$digitsPhone'
        : '+55$digitsPhone';

    final payload = <String, dynamic>{
      'handle': handle,
      'order_nsu': orderNsu,
      'redirect_url': AppConstants.infinitePayRedirectUrl,
      'items': items
          .map(
            (i) => {
              'quantity': i['quantity'],
              'price': i['price'],
              'description': i['description'],
            },
          )
          .toList(),
      if (order.customerName.trim().isNotEmpty)
        'customer': {
          'name': order.customerName.trim(),
          if (digitsPhone.isNotEmpty) 'phone_number': formattedPhone,
        },
    };

    final endpoints = [
      Uri.parse('${AppConstants.infinitePayWorkerUrl}/create-checkout'),
      Uri.parse('https://api.infinitepay.io/invoices/public/checkout/links'),
      Uri.parse('https://api.checkout.infinitepay.io/links'),
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _httpClient
            .post(
              endpoint,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final urlStr = (decoded['url'] ??
                    decoded['checkout_url'] ??
                    decoded['link'] ??
                    '')
                .toString()
                .trim();
            if (urlStr.isNotEmpty) {
              return Uri.parse(urlStr);
            }
          }
        }
      } catch (_) {
        // Continua para o próximo endpoint ou fallback direto
      }
    }

    return buildDirectCheckoutUri(order);
  }

  /// Abre o Checkout da InfinitePay no navegador ou app externo.
  Future<bool> openCheckout(CheckoutOrderModel order) async {
    final uri = await createCheckoutUri(order);
    if (customLauncher != null) {
      return customLauncher!(uri);
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
