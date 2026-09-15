import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:lumen_store/main.dart';

import 'checkout_test.dart' show FakeCommerce;
import 'checkout_test.dart' show MemoryStorage;

import 'package:lumen_store/checkout/commerce_api.dart';
import 'package:lumen_store/account/account_controller.dart';

class FakeProductsRepository implements ProductsRepository {
  @override
  Future<List<StoreProduct>> listProducts({
    String? search,
    int? categoryId,
    int skip = 0,
    int limit = 20,
  }) async => [
    const StoreProduct(
      id: 1,
      name: 'Vestido Aura',
      description: 'Vestido',
      price: 289.90,
      stock: 12,
    ),
  ];
  @override
  Future<StoreProduct> product(int id) async => (await listProducts()).first;
  @override
  Future<List<StoreCategory>> categories() async => [
    const StoreCategory(1, 'Moda feminina'),
  ];
}

void main() {
  testWidgets('shows the Lumen entry and opens the storefront', (tester) async {
    await tester.pumpWidget(
      LumenApp(
        productsRepository: FakeProductsRepository(),
        commerceRepository: FakeCommerce(),
        accountController: AccountController(
          CommerceApi(
            storage: MemoryStorage(),
            accountStorage: MemoryStorage(),
          ),
          favoritesStorage: MemoryStorage(),
        ),
      ),
    );
    expect(find.text('L U M E N'), findsOneWidget);

    await tester.tap(find.text('L U M E N'));
    await tester.pumpAndSettle();

    expect(find.text('Vestido Aura'), findsOneWidget);
    expect(find.text('R\$ 289,90'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byIcon(Icons.add_shopping_cart_rounded),
      200,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_shopping_cart_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Vestido Aura adicionado à sua sacola.'), findsOneWidget);
  });
}
