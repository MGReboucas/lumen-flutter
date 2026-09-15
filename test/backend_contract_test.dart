import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lumen_store/checkout/commerce_api.dart';

import 'checkout_test.dart' show MemoryStorage;

// Enabled only by backend/tests/run_flutter_contract.py; never points to production.
void main() {
  const base = String.fromEnvironment('CONTRACT_API');
  test(
    'Flutter client completes a checkout against the local FastAPI',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      final storage = MemoryStorage();
      final api = CommerceApi(
        client: client,
        storage: storage,
        accountStorage: MemoryStorage(),
        baseUrl: base,
      );
      final cart = await api.cart();
      final products = jsonDecode(
        (await client.get(Uri.parse('$base/products'))).body,
      ) as List;
      final product = products.first as Json;
      await api.setQuantity(product['id'] as int, 2, cart.version);
      final quote = await api.quote();
      final order = await api.checkout({
        'cart_version': quote.cart.version,
        'expected_total_cents': quote.totalCents,
        'payer_email': 'cliente@example.com',
        'payer_document': '52998224725',
        'address': {
          'recipient': 'Cliente Teste',
          'postal_code': '01001000',
          'street': 'Rua Teste',
          'number': '1',
          'district': 'Centro',
          'city': 'São Paulo',
          'state': 'SP',
        },
      }, 'contract-checkout-key');
      expect(order.totalCents, quote.totalCents);
      final paidIntent = await api.pay(order.id);
      expect(paidIntent.sandbox, isTrue);
      final resumed = CommerceApi(
        accountStorage: MemoryStorage(),
        client: client,
        storage: storage,
        baseUrl: base,
      );
      expect((await resumed.cart()).activeOrderId, order.id);
      expect(
        (await resumed.pay(order.id)).payment!['provider_charge_id'],
        paidIntent.payment!['provider_charge_id'],
      );
      // Cancellation round-trip verifies a terminal state and release of stock.
      expect((await resumed.cancel(order.id)).status, 'cancelled');
      expect((await resumed.cart()).activeOrderId, isNull);
      expect((await resumed.orders()).single.id, order.id);
      final nextQuote = await resumed.quote();
      final next = await resumed.checkout({
        'cart_version': nextQuote.cart.version,
        'expected_total_cents': nextQuote.totalCents,
        'payer_email': 'cliente@example.com',
        'payer_document': '52998224725',
        'address': {
          'recipient': 'Cliente Teste',
          'postal_code': '01001000',
          'street': 'Rua Teste',
          'number': '1',
          'district': 'Centro',
          'city': 'São Paulo',
          'state': 'SP',
        },
      }, 'contract-checkout-key-2');
      final nextPayment = await resumed.pay(next.id);
      final event = jsonEncode({
        'id': 'contract-event',
        'type': 'payment.updated',
        'data': {
          'provider_charge_id': nextPayment.payment!['provider_charge_id'],
          'status': 'paid',
        },
      });
      final signature = Hmac(
        sha256,
        utf8.encode('contract-only-secret'),
      ).convert(utf8.encode(event)).toString();
      final confirmed = await client.post(
        Uri.parse('$base/payments/webhooks/provider'),
        headers: {
          'X-Payment-Signature': signature,
          'Content-Type': 'application/json',
        },
        body: event,
      );
      expect(confirmed.statusCode, 200);
      expect((await resumed.refresh(next.id)).paid, isTrue);
      expect((await resumed.cart()).items, isEmpty);
      // Account owns the existing checkout history; the guest token is revoked for it.
      final user = await resumed.signIn(
        'conta@example.com',
        'Minha frase segura 123!',
        true,
      );
      expect(user['email'], 'conta@example.com');
      expect((await resumed.orders()).length, 2);
      final oldGuest = await client.get(
        Uri.parse('$base/cart'),
        headers: {'X-Cart-Token': storage.value!},
      );
      expect(oldGuest.statusCode, 401);
      await resumed.accountRequest('PUT', '/favorites/${product['id']}');
      expect(
        (await resumed.accountRequest('GET', '/favorites') as List).length,
        1,
      );
      await resumed.accountRequest('POST', '/auth/logout');
      await resumed.clearAccount();
      expect((await resumed.orders()), isEmpty);
      await resumed.signIn(
        'conta@example.com',
        'Minha frase segura 123!',
        false,
      );
      expect((await resumed.orders()).length, 2);
      expect(
        (await resumed.accountRequest('GET', '/favorites') as List).length,
        1,
      );
    },
    skip: base.isEmpty ? 'Executar pelo script de contrato no backend.' : false,
  );
}
