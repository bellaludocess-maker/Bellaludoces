import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bella_lu_doces/main.dart';
import 'package:bella_lu_doces/main_admin.dart';
import 'package:bella_lu_doces/core/constants/app_constants.dart';
import 'package:bella_lu_doces/core/utils/currency_formatter.dart';
import 'package:bella_lu_doces/modules/admin/services/admin_image_picker_service.dart';
import 'package:bella_lu_doces/modules/catalog/models/product_model.dart';
import 'package:bella_lu_doces/modules/catalog/models/product_option.dart';
import 'package:bella_lu_doces/modules/cart/models/cart_item_model.dart';
import 'package:bella_lu_doces/modules/checkout/models/checkout_order_model.dart';
import 'package:bella_lu_doces/modules/checkout/services/infinitepay_checkout_service.dart';
import 'package:bella_lu_doces/modules/checkout/services/whatsapp_order_service.dart';
import 'package:bella_lu_doces/modules/external/cloudinary/cloudinary_service.dart';
import 'package:bella_lu_doces/modules/external/config/cloud_config.dart';
import 'package:bella_lu_doces/modules/external/firebase/firestore_catalog_repository.dart';

void main() {
  testWidgets(
      'Módulo 1: Vitrine renderiza os 3 produtos do folder e filtra por categoria',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BellaLuDocesApp());
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.storeName), findsWidgets);
    expect(find.textContaining(AppConstants.storePromoHighlight), findsWidgets);

    expect(find.text('Pipoca Gourmet'), findsOneWidget);
    expect(find.text('R\$ 20,00  |  R\$ 25,00'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Bolo Caseiro'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bolo Caseiro'), findsOneWidget);
    expect(find.text('R\$ 15,00'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1200));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('category_bolos')));
    await tester.pumpAndSettle();

    expect(find.text('Bolo Caseiro'), findsOneWidget);
    expect(find.text('Pipoca Gourmet'), findsNothing);
  });

  testWidgets(
      'Módulo 2: Seleção de sabores, observações e cálculo exato do carrinho',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BellaLuDocesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pipoca Gourmet'));
    await tester.pumpAndSettle();

    final tam25Finder = find.byKey(const ValueKey('option_tam-25'));
    await tester.ensureVisible(tam25Finder);
    await tester.tap(tam25Finder);
    await tester.pumpAndSettle();

    final ninhoFinder = find.byKey(const ValueKey('option_sabor-ninho'));
    await tester.ensureVisible(ninhoFinder);
    await tester.tap(ninhoFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('increase_qty_button')));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar • R\$ 50,00'), findsOneWidget);

    final notesFinder = find.byKey(const ValueKey('product_notes_input'));
    await tester.ensureVisible(notesFinder);
    await tester.enterText(notesFinder, 'Bem crocante por favor');
    await tester.tap(find.byKey(const ValueKey('confirm_add_to_cart_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cart_bar_count_text')), findsOneWidget);
    expect(find.text('2 itens'), findsOneWidget);
    expect(find.text('R\$ 50,00'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('open_cart_bar_button')));
    await tester.pumpAndSettle();

    expect(find.text('Minha Sacola (2)'), findsOneWidget);
    expect(
      find.text('Sabor/Opção: Pacote Especial (R\$ 25,00) • Ninho'),
      findsOneWidget,
    );
    expect(find.text('Obs: "Bem crocante por favor"'), findsOneWidget);
  });

  testWidgets(
      'Módulo 3: Checkout alterna Entrega/Retirada e formata pedido para o WhatsApp oficial',
      (WidgetTester tester) async {
    Uri? launchedUri;
    final mockWhatsAppService = WhatsAppOrderService(
      customLauncher: (uri) async {
        launchedUri = uri;
        return true;
      },
    );

    await tester.pumpWidget(
      BellaLuDocesApp(whatsAppService: mockWhatsAppService),
    );
    await tester.pumpAndSettle();

    // 1. Adiciona 1x Pipoca Gourmet com Creme (R$ 35,00) na sacola
    await tester.tap(find.text('Pipoca Gourmet com Creme'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_add_to_cart_button')));
    await tester.pumpAndSettle();

    // 2. Abre a sacola e avança para o Checkout
    await tester.tap(find.byKey(const ValueKey('open_cart_bar_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proceed_to_checkout_button')));
    await tester.pumpAndSettle();

    // Verifica que inicia em Entrega (+ R$ 10,00) -> Total R$ 45,00
    expect(find.text('Finalizar Pedido'), findsOneWidget);
    expect(find.byKey(const ValueKey('checkout_total_text')), findsOneWidget);
    expect(find.text('R\$ 45,00'), findsOneWidget);

    // Testa alternar para Retirada (R$ 0,00) -> Total R$ 35,00
    await tester.tap(find.byKey(const ValueKey('select_pickup_mode')));
    await tester.pumpAndSettle();
    expect(find.text('Grátis (Combinar com a loja)'), findsOneWidget);

    // Volta para Entrega (+ R$ 10,00) -> Total R$ 45,00
    await tester.tap(find.byKey(const ValueKey('select_delivery_mode')));
    await tester.pumpAndSettle();

    // 2.5 Testa aplicar e remover Cupom de Desconto (VOLTE10 -> 10% OFF sobre R$ 35,00 = - R$ 3,50 -> Total R$ 41,50)
    final couponInput = find.byKey(const ValueKey('checkout_coupon_input'));
    await Scrollable.ensureVisible(tester.element(couponInput));
    await tester.pumpAndSettle();
    await tester.enterText(couponInput, 'VOLTE10');
    await tester.tap(find.byKey(const ValueKey('apply_coupon_button')));
    await tester.pumpAndSettle();
    expect(find.text('- R\$ 3,50'), findsOneWidget);
    expect(find.text('R\$ 41,50'), findsOneWidget);

    // Remove o cupom para validar retorno ao Total R$ 45,00
    await tester.tap(find.byKey(const ValueKey('remove_coupon_button')));
    await tester.pumpAndSettle();
    expect(find.text('R\$ 45,00'), findsOneWidget);

    // 3. Preenche Dados do Cliente e Endereço
    await tester.enterText(
      find.byKey(const ValueKey('checkout_name_input')),
      'Ana Paula',
    );
    await tester.enterText(
      find.byKey(const ValueKey('checkout_phone_input')),
      '(34) 98888-7777',
    );
    await tester.enterText(
      find.byKey(const ValueKey('checkout_street_input')),
      'Av. Brasil, 500',
    );
    await tester.enterText(
      find.byKey(const ValueKey('checkout_neighborhood_input')),
      'Santa Mônica',
    );

    // 4. Rola até o botão de confirmação e envia o pedido para o WhatsApp
    final submitBtn = find.byKey(const ValueKey('submit_whatsapp_order_button'));
    await Scrollable.ensureVisible(tester.element(submitBtn));
    await tester.pumpAndSettle();
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // 5. Valida que o link do WhatsApp oficial foi gerado e disparado com a mensagem completa
    expect(launchedUri, isNotNull);
    expect(launchedUri!.host, 'wa.me');
    expect(launchedUri!.path, '/${AppConstants.whatsappNumberClean}');

    final messageText = launchedUri!.queryParameters['text']!;
    expect(messageText, contains('Ana Paula'));
    expect(messageText, contains('Pipoca Gourmet com Creme'));
    expect(messageText, contains('Taxa de entrega'));
    expect(messageText, contains('34987193964'));
    expect(messageText, contains('Lucineide da Silva'));
    expect(messageText, contains('Av. Brasil, 500'));
    expect(messageText, contains('Santa Mônica'));
    expect(messageText, contains('R\$ 10,00'));
    expect(messageText, contains('R\$ 45,00'));
  });

  testWidgets('Responsividade: Layout adapta entre Mobile (390px) e PC (1440px)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BellaLuDocesApp());
    await tester.pumpAndSettle();
    expect(find.text('Pipoca Gourmet'), findsOneWidget);

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(find.text('Pipoca Gourmet'), findsOneWidget);
    expect(find.text('Pipoca Gourmet com Creme'), findsOneWidget);
  });

  test('CurrencyFormatter formata valores corretamente em BRL', () {
    expect(CurrencyFormatter.formatBRL(10.0), 'R\$ 10,00');
    expect(CurrencyFormatter.formatBRL(15.0), 'R\$ 15,00');
    expect(CurrencyFormatter.formatBRL(20.0), 'R\$ 20,00');
    expect(CurrencyFormatter.formatBRL(25.0), 'R\$ 25,00');
    expect(CurrencyFormatter.formatBRL(35.0), 'R\$ 35,00');
  });

  test(
      'Módulo 4: FirestoreCatalogRepository sincroniza produtos e CloudinaryService otimiza/envia fotos',
      () async {
    final config = CloudConfig(
      firebaseProjectId: 'bella-lu-prod',
      cloudinaryCloudName: 'bella-cloud-real',
      cloudinaryUploadPreset: 'bella_unsigned_preset',
    );

    final mockHttpClient = MockClient((request) async {
      if (request.url.host == 'api.cloudinary.com') {
        return http.Response(
          jsonEncode({
            'secure_url':
                'https://res.cloudinary.com/bella-cloud-real/image/upload/v1/doces/trufa.jpg',
          }),
          200,
        );
      }

      if (request.url.host == 'firestore.googleapis.com' &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'documents': [
              {
                'name':
                    'projects/bella-lu-prod/databases/(default)/documents/products/copo-felicidade',
                'fields': {
                  'id': {'stringValue': 'copo-felicidade'},
                  'name': {'stringValue': 'Copo da Felicidade'},
                  'description': {'stringValue': 'Camadas de brigadeiro e morango'},
                  'imageUrl': {
                    'stringValue':
                        'https://res.cloudinary.com/bella-cloud-real/image/upload/v1/copo.jpg',
                  },
                  'basePrice': {'doubleValue': 28.0},
                  'categoryId': {'stringValue': 'bolos'},
                  'categoryName': {'stringValue': 'Bolos Caseiros'},
                  'isAvailable': {'booleanValue': true},
                  'isReadyDelivery': {'booleanValue': true},
                  'options': {
                    'arrayValue': {
                      'values': [
                        {
                          'mapValue': {
                            'fields': {
                              'id': {'stringValue': 'opt-morango'},
                              'name': {'stringValue': 'Ninho com Morango'},
                              'additionalPrice': {'doubleValue': 0.0},
                              'isAvailable': {'booleanValue': true},
                            },
                          },
                        },
                      ],
                    },
                  },
                },
              },
            ],
          }),
          200,
        );
      }

      return http.Response('{}', 200);
    });

    // 1. Valida upload direto e otimização automática do CloudinaryService
    final cloudinary = CloudinaryService(
      config: config,
      httpClient: mockHttpClient,
    );
    final uploadedUrl = await cloudinary.uploadImageBytes(
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      fileName: 'trufa.jpg',
    );
    expect(uploadedUrl, contains('f_auto,q_auto'));
    expect(uploadedUrl, contains('trufa.jpg'));

    // 2. Valida leitura e stream em tempo real do FirestoreCatalogRepository
    final firestoreRepo = FirestoreCatalogRepository(
      config: config,
      httpClient: mockHttpClient,
    );
    final products = await firestoreRepo.getProducts();
    expect(products.length, 1);
    expect(products.first.name, 'Copo da Felicidade');
    expect(products.first.basePrice, 28.0);
    expect(products.first.flavorNames, contains('Ninho com Morango'));

    // 3. Salva novo produto e verifica atualização imediata
    await firestoreRepo.saveProduct(
      const ProductModel(
        id: 'palha-italiana',
        name: 'Palha Italiana Gourmet',
        description: 'Feita com brigadeiro artesanal',
        imageUrl: 'assets/palha',
        basePrice: 12.0,
        categoryId: 'bolos',
        categoryName: 'Bolos Caseiros',
        options: [ProductOption(id: 'trad', name: 'Tradicional')],
      ),
    );
    final updatedList = await firestoreRepo.getProducts();
    expect(updatedList.any((p) => p.id == 'palha-italiana'), isTrue);
  });

  testWidgets(
      'Módulo 5: App Admin Separado exige PIN, cria novas categorias, cadastra e edita produtos no Mobile (360px)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockPicker = AdminImagePickerService(
      customPicker: () async => PickedProductImage(
        // 1x1 transparent PNG bytes
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        ),
        fileName: 'cesta_especial.png',
      ),
    );

    // 1. Inicia o App Admin Separado (com proteção por PIN)
    await tester.pumpWidget(
      BellaLuAdminApp(imagePickerService: mockPicker),
    );
    await tester.pumpAndSettle();

    expect(find.text('Painel Gestor Exclusivo'), findsOneWidget);

    // 2. Desbloqueia com o PIN da Loja ('2026')
    await tester.enterText(
      find.byKey(const ValueKey('admin_pin_input')),
      '2026',
    );
    await tester.tap(find.byKey(const ValueKey('admin_unlock_button')));
    await tester.pumpAndSettle();

    expect(find.text('Cadastrar Novo Produto no Catálogo'), findsOneWidget);

    // 3. Cria uma nova categoria ("Kits Presente") pelo botão rápido "+ Nova Categoria"
    await tester.tap(
      find.byKey(const ValueKey('admin_quick_add_category_button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('dialog_new_category_input')),
      'Kits Presente',
    );
    await tester.tap(
      find.byKey(const ValueKey('dialog_confirm_category_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Categorias do Cardápio (3)'), findsOneWidget);

    // 4. Preenche os dados do novo produto ("Cesta Especial")
    await tester.enterText(
      find.byKey(const ValueKey('admin_name_input')),
      'Cesta Especial',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin_price_input')),
      '65,00',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin_flavors_input')),
      'Com Caneca, Com Pelúcia',
    );

    // 5. Seleciona foto e publica no cardápio
    await tester.tap(find.byKey(const ValueKey('admin_pick_photo_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('admin_save_product_button')));
    await tester.pumpAndSettle();

    // Verifica que aparece na lista de Produtos Cadastrados do Admin (total 4 produtos)
    expect(find.text('Produtos Cadastrados (4)'), findsOneWidget);

    // 6. Testa editar um produto já existente ("Bolo Caseiro") na janela Pop-up
    final editBoloBtn = find.byKey(const ValueKey('edit_prod_bolo-caseiro'));
    await Scrollable.ensureVisible(tester.element(editBoloBtn));
    await tester.pumpAndSettle();
    await tester.tap(editBoloBtn);
    await tester.pumpAndSettle();

    expect(find.text('Editando: Bolo Caseiro'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('edit_dialog_price_input')),
      '18,00',
    );
    await tester.tap(find.byKey(const ValueKey('edit_dialog_save_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('R\$ 18,00'), findsWidgets);

    // 7. Testa alterar o valor da Taxa de Entrega pelo Painel Admin
    final deliveryFeeInput = find.byKey(
      const ValueKey('admin_delivery_fee_input'),
    );
    await Scrollable.ensureVisible(tester.element(deliveryFeeInput));
    await tester.pumpAndSettle();
    expect(find.text('Taxa de Entrega (R\$ 10,00)'), findsOneWidget);

    await tester.enterText(deliveryFeeInput, '12,50');
    final saveDeliveryFeeBtn = find.byKey(
      const ValueKey('admin_save_delivery_fee_button'),
    );
    await Scrollable.ensureVisible(tester.element(saveDeliveryFeeBtn));
    await tester.pumpAndSettle();
    await tester.tap(saveDeliveryFeeBtn);
    await tester.pumpAndSettle();

    expect(find.text('Taxa de Entrega (R\$ 12,50)'), findsOneWidget);

    // 8. Testa criar um novo Cupom de Desconto pelo Painel Admin
    final couponCodeInput = find.byKey(
      const ValueKey('admin_coupon_code_input'),
    );
    await Scrollable.ensureVisible(tester.element(couponCodeInput));
    await tester.pumpAndSettle();
    await tester.enterText(couponCodeInput, 'DOCE15');
    await tester.enterText(
      find.byKey(const ValueKey('admin_coupon_value_input')),
      '15',
    );
    final saveCouponBtn = find.byKey(
      const ValueKey('admin_save_coupon_button'),
    );
    await Scrollable.ensureVisible(tester.element(saveCouponBtn));
    await tester.pumpAndSettle();
    await tester.tap(saveCouponBtn);
    await tester.pumpAndSettle();

    expect(find.text('DOCE15 • 15% OFF'), findsOneWidget);
  });

  test(
      'InfinitePayCheckoutService envia pedido em centavos para o Cloudflare Worker oficial',
      () async {
    Map<String, dynamic>? capturedPayload;
    Uri? capturedEndpoint;

    final mockClient = MockClient((request) async {
      capturedEndpoint = request.url;
      capturedPayload = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'url':
              'https://checkout.infinitepay.com.br/lucineide-silva-jan/pay-123',
        }),
        200,
      );
    });

    final service = InfinitePayCheckoutService(httpClient: mockClient);
    const order = CheckoutOrderModel(
      id: 'ped-999',
      customerName: 'Cliente Teste',
      customerPhone: '(34) 99999-0000',
      deliveryMethod: DeliveryMethod.delivery,
      paymentMethod: PaymentMethod.pix,
      items: [
        CartItemModel(
          id: 'item-1',
          product: ProductModel(
            id: 'pipoca-gourmet',
            name: 'Pipoca Gourmet',
            description: 'Pipoca artesanal',
            imageUrl: 'assets/images/pipoca_gourmet.jpg',
            basePrice: 20.0,
            categoryId: 'pipocas',
            categoryName: 'Pipocas Gourmet',
            options: [ProductOption(id: 'ninho', name: 'Ninho')],
          ),
          selectedOptions: [ProductOption(id: 'ninho', name: 'Ninho')],
          quantity: 2,
        ),
      ],
    );

    final uri = await service.createCheckoutUri(order);

    expect(
      capturedEndpoint.toString(),
      'https://bellalu-infinitepay.bellaludocess.workers.dev/create-checkout',
    );
    expect(capturedPayload!['handle'], 'lucineide-silva-jan');
    expect(capturedPayload!['order_nsu'], 'ped-999');
    final items = capturedPayload!['items'] as List<dynamic>;
    expect(items.length, 2); // 2x Pipoca (R$ 20 = 2000) + 1x Frete (R$ 10 = 1000)
    expect(items.first['price'], 2000);
    expect(items.first['quantity'], 2);
    expect(
      uri.toString(),
      'https://checkout.infinitepay.com.br/lucineide-silva-jan/pay-123',
    );
  });
}
