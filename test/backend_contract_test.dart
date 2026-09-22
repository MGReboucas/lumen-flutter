import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lumen_store/checkout/commerce_api.dart';

import 'checkout_test.dart' show MemoryStorage;

// Enabled only by backend/tests/run_flutter_contract.py; never points to production.
void main() {
  const base = String.fromEnvironment('CONTRACT_API');
  const provider = String.fromEnvironment(
    'CONTRACT_PROVIDER',
    defaultValue: 'sandbox',
  );
  const providerApi = String.fromEnvironment('CONTRACT_PROVIDER_API');
  const ordersProvider = provider == 'orders';
  test(
    'Flutter client completes account, checkout, webhook and stock flow ($provider)',
    () async {
      void requireLoopback(String value) {
        final uri = Uri.parse(value);
        if (uri.scheme != 'http' || uri.host != '127.0.0.1' || !uri.hasPort) {
          throw StateError(
            'O contrato só pode chamar servidores locais temporários.',
          );
        }
      }

      requireLoopback(base);
      if (ordersProvider) requireLoopback(providerApi);
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
      final originalStock = product['stock'] as int;
      Future<int> stock() async {
        final response = await client.get(
          Uri.parse('$base/products/${product['id']}'),
        );
        expect(response.statusCode, 200);
        return (jsonDecode(response.body) as Json)['stock'] as int;
      }

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
      expect(await stock(), originalStock - 2);
      final paidIntent = await api.pay(order.id);
      expect(paidIntent.sandbox, !ordersProvider);
      expect(
        paidIntent.payment!['provider'],
        ordersProvider ? 'mercadopago_orders' : 'sandbox',
      );
      if (ordersProvider) {
        expect(paidIntent.nextAction['processing'], isTrue);
        final ready = await api.refresh(order.id);
        expect(ready.nextAction['copy_and_paste'], isNotEmpty);
        expect(ready.nextAction['processing'], isFalse);
      }
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
      expect((await resumed.cancel(order.id)).status, 'cancelled');
      expect(await stock(), originalStock);
      expect((await resumed.cart()).activeOrderId, isNull);
      expect((await resumed.orders()).single.id, order.id);
      // Register before the next checkout; the account claims the guest history.
      final user = await resumed.signIn(
        'conta@example.com',
        'Minha frase segura 123!',
        true,
      );
      expect(user['email'], 'conta@example.com');
      final oldGuest = await client.get(
        Uri.parse('$base/cart'),
        headers: {'X-Cart-Token': storage.value!},
      );
      expect(oldGuest.statusCode, 401);
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
      final chargeId = nextPayment.payment!['provider_charge_id'] as String;
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      Future<http.Response> notify({
        bool valid = true,
        String requestId = 'contract-paid',
      }) {
        final event = jsonEncode(
          ordersProvider
              ? {
                  'type': 'order',
                  'data': {'id': chargeId, 'status': 'processed'},
                }
              : {
                  'id': requestId,
                  'type': 'payment.updated',
                  'data': {'provider_charge_id': chargeId, 'status': 'paid'},
                },
        );
        final manifest = ordersProvider
            ? 'id:${chargeId.toLowerCase()};request-id:$requestId;ts:$timestamp;'
            : event;
        final signature = Hmac(
          sha256,
          utf8.encode('contract-only-secret'),
        ).convert(utf8.encode(manifest)).toString();
        return client.post(
          Uri.parse(
            ordersProvider
                ? '$base/payments/webhooks/mercadopago?data.id=$chargeId&type=order'
                : '$base/payments/webhooks/provider',
          ),
          headers: {
            'Content-Type': 'application/json',
            if (ordersProvider) ...{
              'x-request-id': requestId,
              'x-signature':
                  'ts=$timestamp,v1=${valid ? signature : 'invalid'}',
            } else
              'X-Payment-Signature': valid ? signature : 'invalid',
          },
          body: event,
        );
      }

      expect(
        (await notify(valid: false)).statusCode,
        ordersProvider ? 401 : 400,
      );
      expect((await resumed.order(next.id)).pending, isTrue);
      if (ordersProvider) {
        // A signed payload claiming approval is insufficient: provider data wins.
        expect(
          (await notify(requestId: 'contract-still-pending')).statusCode,
          200,
        );
        expect((await resumed.order(next.id)).pending, isTrue);
        final approved = await client.post(
          Uri.parse('$providerApi/_test/paid/$chargeId'),
          headers: {'Authorization': 'Bearer contract-controller-secret'},
        );
        expect(approved.statusCode, 200);
      }
      final confirmed = await notify();
      expect(confirmed.statusCode, 200);
      expect((jsonDecode(confirmed.body) as Json)['status'], 'processed');
      final duplicate = await notify();
      expect(duplicate.statusCode, 200);
      expect((jsonDecode(duplicate.body) as Json)['status'], 'duplicate');
      expect((await resumed.refresh(next.id)).paid, isTrue);
      expect((await resumed.cancel(next.id)).paid, isTrue);
      expect(await stock(), originalStock - 2);
      expect((await resumed.cart()).items, isEmpty);
      expect((await resumed.orders()).length, 2);
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
