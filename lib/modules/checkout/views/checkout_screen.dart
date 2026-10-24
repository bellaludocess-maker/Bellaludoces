import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/bella_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/whatsapp_logo_icon.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../catalog/models/coupon_model.dart';
import '../models/checkout_order_model.dart';
import '../services/infinitepay_checkout_service.dart';
import '../services/whatsapp_order_service.dart';

/// Tela de Checkout & Finalização via WhatsApp e InfinitePay (Módulo 3).
/// Otimizada para Mobile e PC, com cálculo instantâneo de frete (R$ 10,00 ou R$ 0,00).
class CheckoutScreen extends StatefulWidget {
  final CartController cartController;
  final WhatsAppOrderService whatsAppService;
  final InfinitePayCheckoutService? infinitePayService;
  final String pixKey;
  final String pixHolderName;
  final String pixBankName;
  final double deliveryFee;
  final List<CouponModel> availableCoupons;
  final Future<void> Function(CheckoutOrderModel order)? onOrderSubmitted;

  const CheckoutScreen({
    super.key,
    required this.cartController,
    this.whatsAppService = const WhatsAppOrderService(),
    this.infinitePayService,
    this.pixKey = AppConstants.defaultPixKey,
    this.pixHolderName = AppConstants.defaultPixHolderName,
    this.pixBankName = AppConstants.defaultPixBankName,
    this.deliveryFee = AppConstants.defaultDeliveryFee,
    this.availableCoupons = const [],
    this.onOrderSubmitted,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _referenceController = TextEditingController();
  final _changeController = TextEditingController();
  final _couponController = TextEditingController();
  late final InfinitePayCheckoutService _infinitePayService;

  DeliveryMethod _deliveryMethod = DeliveryMethod.delivery;
  PaymentMethod _paymentMethod = PaymentMethod.pix;
  CouponModel? _appliedCoupon;
  String? _couponFeedbackMessage;
  bool _couponFeedbackIsError = false;
  bool _isSending = false;
  bool _isOpeningInfinitePay = false;

  @override
  void initState() {
    super.initState();
    _infinitePayService =
        widget.infinitePayService ?? InfinitePayCheckoutService();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _neighborhoodController.dispose();
    _referenceController.dispose();
    _changeController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  double get _subtotal => widget.cartController.subtotal;
  double get _deliveryFee =>
      _deliveryMethod == DeliveryMethod.delivery ? widget.deliveryFee : 0.0;

  double get _discountAmount {
    final coupon = _appliedCoupon;
    if (coupon == null) return 0.0;
    final validationError = coupon.validate(
      subtotal: _subtotal,
      customerPhone: _phoneController.text,
    );
    if (validationError != null) return 0.0;
    return coupon.calculateDiscount(
      subtotal: _subtotal,
      deliveryFee: _deliveryFee,
    );
  }

  double get _total {
    final raw = _subtotal + _deliveryFee - _discountAmount;
    final clamped = raw < 0.0 ? 0.0 : raw;
    return double.parse(clamped.toStringAsFixed(2));
  }

  void _handleApplyCoupon() {
    final rawCode = _couponController.text.trim().toUpperCase();
    if (rawCode.isEmpty) {
      setState(() {
        _appliedCoupon = null;
        _couponFeedbackIsError = true;
        _couponFeedbackMessage = 'Digite o código do cupom.';
      });
      return;
    }

    CouponModel? matched;
    for (final c in widget.availableCoupons) {
      if (c.normalizedCode == rawCode) {
        matched = c;
        break;
      }
    }

    if (matched == null) {
      setState(() {
        _appliedCoupon = null;
        _couponFeedbackIsError = true;
        _couponFeedbackMessage = 'Cupom "$rawCode" não encontrado.';
      });
      return;
    }

    final error = matched.validate(
      subtotal: _subtotal,
      customerPhone: _phoneController.text,
    );
    if (error != null) {
      setState(() {
        _appliedCoupon = null;
        _couponFeedbackIsError = true;
        _couponFeedbackMessage = error;
      });
      return;
    }

    setState(() {
      _appliedCoupon = matched;
      _couponFeedbackIsError = false;
      final savedVal = matched!.calculateDiscount(
        subtotal: _subtotal,
        deliveryFee: _deliveryFee,
      );
      _couponFeedbackMessage =
          'Cupom ${matched.normalizedCode} aplicado! Economia de ${CurrencyFormatter.formatBRL(savedVal)}';
    });
  }

  void _handleRemoveCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponController.clear();
      _couponFeedbackMessage = null;
      _couponFeedbackIsError = false;
    });
  }

  CheckoutOrderModel _buildOrderModel() {
    final activeDiscount = _discountAmount;
    final activeCode =
        activeDiscount > 0 && _appliedCoupon != null
            ? _appliedCoupon!.normalizedCode
            : '';
    return CheckoutOrderModel(
      id: 'ped-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now().toIso8601String(),
      customerName: _nameController.text,
      customerPhone: _phoneController.text,
      deliveryMethod: _deliveryMethod,
      streetAddress: _streetController.text,
      neighborhood: _neighborhoodController.text,
      referencePoint: _referenceController.text,
      paymentMethod: _paymentMethod,
      changeFor: _changeController.text,
      pixKey: widget.pixKey,
      pixHolderName: widget.pixHolderName,
      pixBankName: widget.pixBankName,
      customDeliveryFee: widget.deliveryFee,
      couponCode: activeCode,
      discountAmount: activeDiscount,
      items: widget.cartController.items,
    );
  }

  Future<void> _payWithInfinitePay() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BellaColors.errorRed,
          content: Text(
            'Preencha seu Nome, WhatsApp e Endereço acima antes de abrir o pagamento.',
          ),
        ),
      );
      return;
    }

    setState(() => _isOpeningInfinitePay = true);
    final order = _buildOrderModel();

    if (widget.onOrderSubmitted != null) {
      try {
        await widget.onOrderSubmitted!(order);
      } catch (_) {}
    }

    try {
      await _infinitePayService.openCheckout(order);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isOpeningInfinitePay = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: BellaColors.successGreen,
        content: Text(
          'Checkout InfinitePay aberto! Após pagar, clique em "Confirmar Pedido no WhatsApp" abaixo.',
        ),
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSending = true);
    final order = _buildOrderModel();
    final formattedMessage = widget.whatsAppService.formatOrderMessage(order);

    // 1. Grava o pedido automaticamente no Painel Admin / Firebase
    if (widget.onOrderSubmitted != null) {
      try {
        await widget.onOrderSubmitted!(order);
      } catch (_) {
        // Continua o fluxo do WhatsApp mesmo se estiver offline
      }
    }

    // 2. Abre o WhatsApp da loja com o pedido completo para envio + comprovante
    bool launched = false;
    try {
      launched = await widget.whatsAppService.sendOrderToWhatsApp(order);
    } catch (_) {
      launched = false;
    }

    if (!mounted) return;
    setState(() => _isSending = false);

    // Exibe modal de confirmação com o resumo pronto (e opção de copiar texto caso esteja em PC sem WhatsApp)
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: BellaColors.whatsappDark,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  launched
                      ? 'Pedido Enviado ao WhatsApp!'
                      : 'Pedido Pronto para o WhatsApp!',
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Confira o resumo gerado para ${AppConstants.whatsappDisplay}:',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: BellaColors.pinkSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: BellaColors.pinkBorder),
                    ),
                    child: SelectableText(
                      formattedMessage,
                      key: const ValueKey('order_summary_preview_text'),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: BellaColors.darkChocolate,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: formattedMessage));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Resumo copiado para a área de transferência!'),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar Pedido'),
            ),
            ElevatedButton(
              key: const ValueKey('finish_order_dialog_button'),
              onPressed: () {
                widget.cartController.clearCart();
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Concluir'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finalizar Pedido'),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: BellaColors.pinkBorder),
            ),
            boxShadow: [
              BoxShadow(
                color: BellaColors.darkChocolate.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 740),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const ValueKey('submit_whatsapp_order_button'),
                  onPressed: _isSending ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BellaColors.whatsappDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const WhatsAppLogoIcon(
                    size: 22,
                    backgroundColor: Colors.white,
                    iconColor: BellaColors.whatsappDark,
                  ),
                  label: Text(
                    'Confirmar Pedido no WhatsApp • ${CurrencyFormatter.formatBRL(_total)}',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              key: const ValueKey('checkout_scroll_view'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Alternador Entrega (+ R$ 10,00) vs Retirada (R$ 0,00)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1. Como deseja receber seu pedido?',
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _DeliveryOptionCard(
                                  key: const ValueKey('select_delivery_mode'),
                                  icon: Icons.delivery_dining_rounded,
                                  title: 'Entrega',
                                  subtitle:
                                      '+ ${CurrencyFormatter.formatBRL(widget.deliveryFee)}',
                                  isSelected: _deliveryMethod ==
                                      DeliveryMethod.delivery,
                                  onTap: () => setState(
                                    () => _deliveryMethod =
                                        DeliveryMethod.delivery,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _DeliveryOptionCard(
                                  key: const ValueKey('select_pickup_mode'),
                                  icon: Icons.storefront_rounded,
                                  title: 'Retirada',
                                  subtitle: 'Combinar com a loja',
                                  isSelected:
                                      _deliveryMethod == DeliveryMethod.pickup,
                                  onTap: () => setState(
                                    () =>
                                        _deliveryMethod = DeliveryMethod.pickup,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_deliveryMethod == DeliveryMethod.pickup) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: BellaColors.pinkSoft,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: BellaColors.pinkBorder),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: BellaColors.pinkPrimary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Retirada sem taxa! Ao enviar o pedido no WhatsApp, combine o horário e local de retirada com a loja.',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: BellaColors.darkChocolate,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Dados do Cliente
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '2. Seus Dados',
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const ValueKey('checkout_name_input'),
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Seu Nome *',
                              hintText: 'Ex: Maria Silva',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Por favor, informe seu nome.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('checkout_phone_input'),
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Seu Telefone / WhatsApp *',
                              hintText: 'Ex: (34) 99999-9999',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Por favor, informe seu telefone.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Endereço de Entrega (Exibido apenas se Entrega estiver selecionada)
                  if (_deliveryMethod == DeliveryMethod.delivery) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '3. Endereço de Entrega',
                              style: textTheme.titleLarge,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const ValueKey('checkout_street_input'),
                              controller: _streetController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Rua / Avenida e Número *',
                                hintText: 'Ex: Rua das Flores, 123, Apto 10',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                              validator: (value) {
                                if (_deliveryMethod ==
                                        DeliveryMethod.delivery &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Informe o endereço para entrega.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key:
                                  const ValueKey('checkout_neighborhood_input'),
                              controller: _neighborhoodController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Bairro *',
                                hintText: 'Ex: Centro',
                                prefixIcon: Icon(Icons.map_outlined),
                              ),
                              validator: (value) {
                                if (_deliveryMethod ==
                                        DeliveryMethod.delivery &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Informe o bairro para entrega.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('checkout_reference_input'),
                              controller: _referenceController,
                              decoration: const InputDecoration(
                                labelText: 'Ponto de Referência (Opcional)',
                                hintText: 'Ex: Próximo à praça principal',
                                prefixIcon: Icon(Icons.explore_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. Forma de Pagamento
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _deliveryMethod == DeliveryMethod.delivery
                                ? '4. Forma de Pagamento'
                                : '3. Forma de Pagamento',
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          ...PaymentMethod.values.map((method) {
                            final isSelected = _paymentMethod == method;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                key: ValueKey('payment_${method.name}'),
                                borderRadius: BorderRadius.circular(14),
                                onTap: () =>
                                    setState(() => _paymentMethod = method),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? BellaColors.pinkSoft
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? BellaColors.pinkPrimary
                                          : BellaColors.pinkBorder,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked_rounded
                                            : Icons.radio_button_off_rounded,
                                        color: isSelected
                                            ? BellaColors.pinkPrimary
                                            : BellaColors.softCocoa,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        method.label,
                                        style: textTheme.bodyLarge?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (_paymentMethod == PaymentMethod.pix) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: BellaColors.pinkSoft,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: BellaColors.pinkPrimary,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.qr_code_rounded,
                                        color: BellaColors.pinkPrimary,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Dados para Pagamento via Pix',
                                          style:
                                              textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: BellaColors.darkChocolate,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Chave Pix: ${widget.pixKey}',
                                    key: const ValueKey('checkout_pix_key_text'),
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: BellaColors.darkChocolate,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Favorecido: ${widget.pixHolderName}',
                                    key: const ValueKey(
                                      'checkout_pix_holder_text',
                                    ),
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: BellaColors.mediumBrown,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Banco: ${widget.pixBankName}',
                                    key: const ValueKey(
                                      'checkout_pix_bank_text',
                                    ),
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: BellaColors.darkChocolate,
                                    ),
                                  ),
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                      key: const ValueKey('copy_pix_key_button'),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: widget.pixKey),
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            backgroundColor:
                                                BellaColors.successGreen,
                                            content: Text(
                                              'Chave Pix (${widget.pixKey}) copiada! Após pagar, envie o comprovante no WhatsApp.',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Copiar Chave Pix'),
                                    ),
                                    const SizedBox(height: 10),
                                    const Divider(
                                      color: BellaColors.pinkBorder,
                                      height: 1,
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton.icon(
                                      key: const ValueKey(
                                        'pay_infinitepay_pix_button',
                                      ),
                                      onPressed: _isOpeningInfinitePay
                                          ? null
                                          : _payWithInfinitePay,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF00A868),
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: _isOpeningInfinitePay
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.flash_on_rounded,
                                              size: 18,
                                            ),
                                      label: const Text(
                                        'Pagar Online via InfinitePay (Pix / Cartão)',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_paymentMethod == PaymentMethod.card) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: BellaColors.pinkSoft,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: BellaColors.pinkPrimary,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.credit_card_rounded,
                                          color: BellaColors.pinkPrimary,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Pagamento Online via InfinitePay (\$${AppConstants.infinitePayHandle})',
                                            style: textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: BellaColors.darkChocolate,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Você pode pagar agora pelo link seguro da InfinitePay (Cartão ou Pix) ou na entrega/retirada.',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: BellaColors.mediumBrown,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton.icon(
                                      key: const ValueKey(
                                        'pay_infinitepay_card_button',
                                      ),
                                      onPressed: _isOpeningInfinitePay
                                          ? null
                                          : _payWithInfinitePay,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF00A868),
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: _isOpeningInfinitePay
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.lock_outline_rounded,
                                              size: 18,
                                            ),
                                      label: const Text(
                                        'Pagar Agora com Cartão / Pix (InfinitePay)',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          if (_paymentMethod == PaymentMethod.cash) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              key: const ValueKey('checkout_change_input'),
                              controller: _changeController,
                              decoration: const InputDecoration(
                                labelText: 'Precisa de troco para quanto?',
                                hintText: 'Ex: R\$ 50,00 (ou deixe em branco)',
                                prefixIcon: Icon(Icons.payments_outlined),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Resumo Financeiro do Pedido
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Resumo do Pedido',
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          ...widget.cartController.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.quantity}x ${item.product.name} (${item.selectedOptionsSummary})',
                                      style: textTheme.bodyMedium,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    CurrencyFormatter.formatBRL(
                                      item.totalPrice,
                                    ),
                                    style: textTheme.labelLarge,
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 22),

                          // Campo de Cupom de Desconto
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: BellaColors.pinkSoft.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: BellaColors.pinkBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.local_offer_rounded,
                                      size: 18,
                                      color: BellaColors.pinkPrimary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tem um cupom de desconto?',
                                      style: textTheme.labelLarge?.copyWith(
                                        color: BellaColors.darkChocolate,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        key: const ValueKey(
                                          'checkout_coupon_input',
                                        ),
                                        controller: _couponController,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        decoration: const InputDecoration(
                                          hintText: 'Digite o código (Ex: VOLTE10)',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_appliedCoupon != null &&
                                        _discountAmount > 0)
                                      OutlinedButton.icon(
                                        key: const ValueKey(
                                          'remove_coupon_button',
                                        ),
                                        onPressed: _handleRemoveCoupon,
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Remover'),
                                      )
                                    else
                                      ElevatedButton(
                                        key: const ValueKey(
                                          'apply_coupon_button',
                                        ),
                                        onPressed: _handleApplyCoupon,
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                        ),
                                        child: const Text('Aplicar'),
                                      ),
                                  ],
                                ),
                                if (_couponFeedbackMessage != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _couponFeedbackMessage!,
                                    key: const ValueKey(
                                      'coupon_feedback_text',
                                    ),
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: _couponFeedbackIsError
                                          ? BellaColors.errorRed
                                          : BellaColors.successGreen,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal', style: textTheme.bodyLarge),
                              Text(
                                CurrencyFormatter.formatBRL(_subtotal),
                                style: textTheme.bodyLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Taxa de Entrega',
                                style: textTheme.bodyLarge,
                              ),
                              Text(
                                _deliveryFee > 0
                                    ? CurrencyFormatter.formatBRL(_deliveryFee)
                                    : 'Grátis (Combinar com a loja)',
                                key: const ValueKey('checkout_fee_text'),
                                style: textTheme.bodyLarge?.copyWith(
                                  color: _deliveryFee > 0
                                      ? BellaColors.darkChocolate
                                      : BellaColors.successGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (_discountAmount > 0 && _appliedCoupon != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Desconto (${_appliedCoupon!.normalizedCode})',
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: BellaColors.successGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '- ${CurrencyFormatter.formatBRL(_discountAmount)}',
                                  key: const ValueKey(
                                    'checkout_discount_text',
                                  ),
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: BellaColors.successGreen,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total a Pagar', style: textTheme.titleLarge),
                              Text(
                                CurrencyFormatter.formatBRL(_total),
                                key: const ValueKey('checkout_total_text'),
                                style: textTheme.headlineMedium?.copyWith(
                                  color: BellaColors.pinkPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveryOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeliveryOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? BellaColors.pinkSoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? BellaColors.pinkPrimary : BellaColors.pinkBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? BellaColors.pinkPrimary
                  : BellaColors.mediumBrown,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: BellaColors.pinkDark,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
