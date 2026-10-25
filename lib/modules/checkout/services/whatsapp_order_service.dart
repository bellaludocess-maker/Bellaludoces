import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/checkout_order_model.dart';

/// Assinatura para injeção opcional de lançador de URL (facilita testes locais).
typedef UrlLauncherCallback = Future<bool> Function(Uri uri);

/// Serviço responsável por formatar o pedido da Bella Lu Doces e disparar
/// o link oficial do WhatsApp `(34) 9.9116-8044`.
class WhatsAppOrderService {
  final UrlLauncherCallback? customLauncher;

  const WhatsAppOrderService({this.customLauncher});

  /// Gera a mensagem estruturada com itens, sabores, entrega e totais.
  String formatOrderMessage(CheckoutOrderModel order) {
    final buffer = StringBuffer();

    buffer.writeln('*NOVO PEDIDO - ${AppConstants.storeName.toUpperCase()}*');
    buffer.writeln('----------------------------------');
    buffer.writeln('*Cliente:* ${order.customerName.trim()}');
    buffer.writeln('*Telefone:* ${order.customerPhone.trim()}');
    buffer.writeln('');

    buffer.writeln('*ITENS DO PEDIDO:*');
    for (final item in order.items) {
      buffer.writeln(
        '• *${item.quantity}x ${item.product.name}* (${CurrencyFormatter.formatBRL(item.totalPrice)})',
      );
      buffer.writeln('   _Sabor/Opção:_ ${item.selectedOptionsSummary}');
      if (item.notes.trim().isNotEmpty) {
        buffer.writeln('   _Obs:_ ${item.notes.trim()}');
      }
    }
    if (order.deliveryMethod == DeliveryMethod.delivery) {
      buffer.writeln(
        '• *1x Taxa de entrega:* ${CurrencyFormatter.formatBRL(order.deliveryFee)}',
      );
    }
    buffer.writeln('----------------------------------');

    if (order.deliveryMethod == DeliveryMethod.delivery) {
      buffer.writeln('*Modalidade:* Entrega em Domicílio');
      buffer.writeln('*Endereço:* ${order.streetAddress.trim()}');
      buffer.writeln('*Bairro:* ${order.neighborhood.trim()}');
      if (order.referencePoint.trim().isNotEmpty) {
        buffer.writeln('*Referência:* ${order.referencePoint.trim()}');
      }
    } else {
      if (order.pickupAddress.trim().isNotEmpty) {
        buffer.writeln('*Modalidade:* Retirada no Local');
        buffer.writeln('*Endereço para Retirada:* ${order.pickupAddress.trim()}');
      } else {
        buffer.writeln(
          '*Modalidade:* Retirada (Combinar horário e retirada com a loja)',
        );
      }
    }
    buffer.writeln('');

    buffer.writeln('*Forma de Pagamento:* ${order.paymentMethod.label}');
    if (order.paymentMethod == PaymentMethod.pix) {
      buffer.writeln(
        '*Chave Pix:* ${order.pixKey} (${order.pixHolderName} • Banco: ${order.pixBankName})',
      );
    } else if (order.paymentMethod == PaymentMethod.cash &&
        order.changeFor.trim().isNotEmpty) {
      buffer.writeln('*Troco para:* ${order.changeFor.trim()}');
    }
    buffer.writeln('----------------------------------');

    buffer.writeln(
      '*Subtotal dos Produtos:* ${CurrencyFormatter.formatBRL(order.subtotal)}',
    );
    if (order.deliveryMethod == DeliveryMethod.delivery) {
      buffer.writeln(
        '*Taxa de entrega:* ${CurrencyFormatter.formatBRL(order.deliveryFee)}',
      );
    } else {
      buffer.writeln(
        '*Taxa de Entrega:* Grátis (Retirada - combinar com a loja)',
      );
    }
    if (order.discountAmount > 0) {
      final couponLabel = order.couponCode.trim().isNotEmpty
          ? ' (${order.couponCode.trim().toUpperCase()})'
          : '';
      buffer.writeln(
        '*Desconto$couponLabel:* - ${CurrencyFormatter.formatBRL(order.discountAmount)}',
      );
    }
    buffer.writeln(
      '*TOTAL DO PEDIDO: ${CurrencyFormatter.formatBRL(order.total)}*',
    );
    if (order.paymentMethod == PaymentMethod.pix) {
      buffer.writeln('');
      buffer.writeln('_Segue abaixo o comprovante do Pix!_');
    }

    return buffer.toString().trim();
  }

  /// Constrói a URI `https://wa.me/5534991168044?text=...` devidamente codificada.
  Uri buildWhatsAppUri(CheckoutOrderModel order) {
    final message = formatOrderMessage(order);
    return Uri.https(
      'wa.me',
      '/${AppConstants.whatsappNumberClean}',
      {'text': message},
    );
  }

  /// Dispara a abertura do WhatsApp no celular ou WhatsApp Web no PC.
  Future<bool> sendOrderToWhatsApp(CheckoutOrderModel order) async {
    final uri = buildWhatsAppUri(order);
    if (customLauncher != null) {
      return customLauncher!(uri);
    }

    return launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}
