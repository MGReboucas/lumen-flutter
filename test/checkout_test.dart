import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumen_store/checkout/commerce_api.dart';
import 'package:lumen_store/checkout/checkout_pages.dart';

Json cartJson({String? active, int quantity = 2, int version = 1}) => {
  'version': version,
  'subtotal_cents': quantity * 3990,
  'active_order_id': active,
  'items': quantity == 0
      ? []
      : [
          {
            'product_id': 1,
            'name': 'Vestido',
            'quantity': quantity,
            'unit_price_cents': 3990,
            'stock': 3,
            'available': true,
          },
        ],
};

Json orderJson({
  String status = 'awaiting_payment',
  bool payment = true,
  bool sandbox = true,
}) => {
  'id': '12345678-order',
  'status': status,
  'total_cents': 9480,
  'subtotal_cents': 7980,
  'shipping_cents': 1500,
  'shipping_label': 'Entrega padrão',
  'items': cartJson()['items'],
  'address': {
    'street': 'Rua Teste',
    'number': '1',
    'city': 'São Paulo',
    'state': 'SP',
  },
  'created_at': '2026-09-15T12:00:00Z',
  'expires_at': '2026-09-15T12:30:00Z',
  'payment': payment
      ? {
          'provider': sandbox ? 'sandbox' : 'mercadopago',
          'status': status == 'paid' ? 'paid' : 'pending',
          'provider_charge_id': 'provider-1',
          'next_action': {
            'copy_and_paste': 'PIX-CODE',
            'qr_code_base64': 'invalid!',
          },
        }
      : null,
};

class MemoryStorage implements SessionStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class FakeCommerce implements CommerceRepository {
  Json data = cartJson();
  String status = 'awaiting_payment';
  bool failFirst = false;
  bool sandbox = true;
  int checkouts = 0;
  final keys = <String>[];
  final requests = <Json>[];
  @override
  Future<CartSnapshot> cart() async => CartSnapshot.fromJson(data);
  @override
  Future<CartSnapshot> setQuantity(
    int productId,
    int quantity,
    int version,
  ) async {
    data = cartJson(quantity: quantity, version: version + 1);
    return cart();
  }

  @override
  Future<CheckoutQuote> quote() async => CheckoutQuote.fromJson({
    ...data,
    'shipping_cents': 1500,
    'total_cents': 9480,
    'shipping_label': 'Entrega padrão',
    'shipping_days': 7,
  });
  @override
  Future<StoreOrder> checkout(Json request, String idempotencyKey) async {
    keys.add(idempotencyKey);
    requests.add(request);
    checkouts++;
    if (failFirst && checkouts == 1) {
      throw const CommerceException('Conexão interrompida.');
    }
    return order('12345678-order');
  }

  @override
  Future<StoreOrder> order(String id) async =>
      StoreOrder.fromJson(orderJson(status: status, sandbox: sandbox));
  @override
  Future<List<StoreOrder>> orders() async => [await order('12345678-order')];
  @override
  Future<StoreOrder> pay(String id) => order(id);
  @override
  Future<StoreOrder> refresh(String id) {
    status = 'paid';
    return order(id);
  }

  @override
  Future<StoreOrder> cancel(String id) {
    status = 'cancelled';
    return order(id);
  }
}

class AsyncPixCommerce extends FakeCommerce {
  bool ready = false;
  @override
  Future<StoreOrder> order(String id) async {
    final data = orderJson(sandbox: false);
    final payment = data['payment'] as Json;
    payment['provider'] = 'mercadopago_orders';
    if (!ready) payment['next_action'] = {'processing': true};
    return StoreOrder.fromJson(data);
  }

  @override
  Future<StoreOrder> refresh(String id) {
    ready = true;
    return order(id);
  }
}

Future<void> fillCheckout(WidgetTester tester) async {
  for (final entry in {
    'email': 'cliente@example.com',
    'document': '52998224725',
    'recipient': 'Cliente Teste',
    'postal_code': '01001000',
    'street': 'Rua Teste',
    'number': '1',
    'district': 'Centro',
    'city': 'São Paulo',
    'state': 'SP',
  }.entries) {
    final field = find.byKey(ValueKey(entry.key));
    await tester.scrollUntilVisible(
      field,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(field, entry.value);
  }
  tester.testTextInput.hide();
  await tester.scrollUntilVisible(
    find.text('CONFIRMAR E GERAR PIX'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  test('API persists the session and sends no client charge amount', () async {
    final storage = MemoryStorage();
    var sessions = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/cart') && request.method == 'POST') {
        sessions++;
        return http.Response(
          jsonEncode({'token': 'secret-session', 'cart': cartJson()}),
          201,
        );
      }
      expect(request.headers['X-Cart-Token'], 'secret-session');
      if (request.url.path.endsWith('/orders') && request.method == 'POST') {
        final body = jsonDecode(request.body) as Json;
        expect(body.containsKey('amount'), isFalse);
        expect(request.headers['Idempotency-Key'], 'checkout-key');
        return http.Response(jsonEncode(orderJson()), 201);
      }
      return http.Response(jsonEncode(cartJson()), 200);
    });
    final api = CommerceApi(
      accountStorage: MemoryStorage(),
      client: client,
      storage: storage,
      baseUrl: 'https://example.com/api/v1',
    );
    await Future.wait([api.cart(), api.cart()]);
    final restarted = CommerceApi(
      accountStorage: MemoryStorage(),
      client: client,
      storage: storage,
      baseUrl: 'https://example.com/api/v1',
    );
    await restarted.cart();
    await restarted.checkout({
      'cart_version': 1,
      'expected_total_cents': 9480,
    }, 'checkout-key');
    expect(sessions, 1);
  });

  test('API handles HTML errors and validation arrays', () async {
    for (final body in ['bad gateway', '{"detail":[{"msg":"invalid"}]}']) {
      final storage = MemoryStorage()..value = 'token';
      final api = CommerceApi(
        accountStorage: MemoryStorage(),
        storage: storage,
        client: MockClient((_) async => http.Response(body, 422)),
      );
      await expectLater(api.cart(), throwsA(isA<CommerceException>()));
    }
  });

  test('CPF/CNPJ validation rejects repeated digits and invalid checksum', () {
    expect(validDocument('52998224725'), isTrue);
    expect(validDocument('11222333000181'), isTrue);
    expect(validDocument('11111111111'), isFalse);
    expect(validDocument('52998224726'), isFalse);
  });

  testWidgets('bag updates quantity and removes items', (tester) async {
    final repo = FakeCommerce();
    await tester.pumpWidget(MaterialApp(home: BagPage(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('R\$ 79,80'), findsOneWidget);
    await tester.tap(find.byTooltip('Diminuir quantidade'));
    await tester.pumpAndSettle();
    expect(repo.data['items'][0]['quantity'], 1);
    await tester.tap(find.byTooltip('Remover produto'));
    await tester.pumpAndSettle();
    expect(find.text('Sua sacola está vazia.'), findsOneWidget);
  });

  testWidgets(
    'checkout retries the same immutable request then confirms payment',
    (tester) async {
      final repo = FakeCommerce()..failFirst = true;
      await tester.pumpWidget(
        MaterialApp(home: CheckoutPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await fillCheckout(tester);
      await tester.tap(find.text('CONFIRMAR E GERAR PIX'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('RETOMAR TENTATIVA'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('RETOMAR TENTATIVA'));
      await tester.pumpAndSettle();
      expect(repo.keys[0], repo.keys[1]);
      expect(repo.requests[0], repo.requests[1]);
      expect(repo.requests[0].containsKey('amount'), isFalse);
      expect(find.textContaining('Pagamento de demonstração'), findsOneWidget);
      expect(find.text('COPIAR PIX'), findsNothing);
      await tester.ensureVisible(find.text('VERIFICAR PAGAMENTO'));
      await tester.tap(find.text('VERIFICAR PAGAMENTO'));
      await tester.pumpAndSettle();
      expect(find.text('Pagamento aprovado'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('invalid form never creates an order', (tester) async {
    final repo = FakeCommerce();
    await tester.pumpWidget(MaterialApp(home: CheckoutPage(repository: repo)));
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    await tester.scrollUntilVisible(
      find.text('CONFIRMAR E GERAR PIX'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONFIRMAR E GERAR PIX'));
    await tester.pumpAndSettle();
    expect(repo.checkouts, 0);
  });

  testWidgets('live PIX keeps copy code available when QR image is invalid', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final repo = FakeCommerce()..sandbox = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OrderPage(orderId: '12345678-order', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PIX-CODE'), findsOneWidget);
    expect(find.textContaining('Pagamento de demonstração'), findsNothing);
    await tester.ensureVisible(find.text('COPIAR PIX'));
    await tester.tap(find.text('COPIAR PIX'));
    await tester.pumpAndSettle();
    expect(copied, 'PIX-CODE');
    expect(find.text('Código PIX copiado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Orders shows preparation and fetches PIX on the next poll', (
    tester,
  ) async {
    final repo = AsyncPixCommerce();
    await tester.pumpWidget(
      MaterialApp(home: OrderPage(orderId: '12345678-order', repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Seu PIX está sendo preparado'), findsOneWidget);
    expect(find.text('COPIAR PIX'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.textContaining('Seu PIX está sendo preparado'), findsNothing);
    expect(find.text('PIX-CODE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pending order can be resumed from bag and cancelled', (
    tester,
  ) async {
    final repo = FakeCommerce()..data = cartJson(active: '12345678-order');
    await tester.pumpWidget(MaterialApp(home: BagPage(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RETOMAR PEDIDO'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CANCELAR PEDIDO'));
    await tester.tap(find.text('CANCELAR PEDIDO'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('CANCELAR PEDIDO'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pedido cancelado'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
