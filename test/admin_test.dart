import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumen_store/admin/admin_api.dart';
import 'package:lumen_store/admin/admin_pages.dart';
import 'package:lumen_store/account/account_pages.dart';
import 'package:lumen_store/checkout/commerce_api.dart';
import 'package:lumen_store/store/catalog_api.dart';

import 'account_pages_test.dart' show accountForTest;
import 'checkout_test.dart' show MemoryStorage;

Json productData({int version = 0, int stock = 5}) => {
  'id': 1,
  'name': 'Vestido Aura',
  'description': 'Cetim',
  'price_cents': 12990,
  'stock': stock,
  'category_id': null,
  'category_name': null,
  'image_url': null,
  'is_active': true,
  'version': version,
};

class FakeAdmin implements AdminRepository {
  Json item = productData();
  Json? saved;
  bool denied = false, conflict = false;
  int saves = 0;
  String? newCategory;
  @override
  Future<List<AdminProduct>> products({
    String search = '',
    bool? active,
    int skip = 0,
  }) async {
    if (denied) {
      throw const CommerceException(
        'Acesso restrito à administração da loja.',
        403,
      );
    }
    return [AdminProduct.fromJson(item)];
  }

  @override
  Future<AdminProduct> product(int id) async => AdminProduct.fromJson(item);
  @override
  Future<List<StoreCategory>> categories() async => [
    const StoreCategory(1, 'Moda'),
  ];
  @override
  Future<StoreCategory> createCategory(String name) async {
    newCategory = name;
    return StoreCategory(2, name);
  }

  @override
  Future<AdminProduct> save(Json data, {int? id}) async {
    saves++;
    if (conflict) {
      throw const CommerceException(
        'O produto ou estoque mudou. Recarregue os dados antes de salvar.',
        409,
      );
    }
    saved = data;
    item = {...item, ...data, 'version': (item['version'] as int) + 1};
    return AdminProduct.fromJson(item);
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'AdminApi sends account session and integer cents to protected endpoints',
    () async {
      final token = MemoryStorage();
      await token.write('admin-session');
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer admin-session');
        expect(request.headers.containsKey('X-Cart-Token'), isFalse);
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/admin/products/1');
        final data = jsonDecode(request.body) as Json;
        expect(data['price_cents'], 12990);
        expect(data['version'], 2);
        return http.Response(jsonEncode({...productData(), ...data}), 200);
      });
      addTearDown(client.close);
      final api = AdminApi(
        CommerceApi(
          client: client,
          accountStorage: token,
          storage: MemoryStorage(),
          baseUrl: 'http://localhost/api/v1',
        ),
      );
      await api.save({'price_cents': 12990, 'version': 2}, id: 1);
    },
  );

  testWidgets('profile only shows administration for an admin account', (
    tester,
  ) async {
    final account = accountForTest();
    addTearDown(account.dispose);
    await account.initialize();
    account.user = {
      'id': 1,
      'email': 'customer@example.com',
      'is_admin': false,
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePage(account: account, onOrders: () {}),
        ),
      ),
    );
    expect(find.text('Administrar loja'), findsNothing);
    account.user = {...account.user!, 'is_admin': true};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePage(
            key: const ValueKey('admin'),
            account: account,
            onOrders: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Administrar loja'), findsOneWidget);
  });

  testWidgets('permission failure hides product data and create action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminCatalogPage(repository: FakeAdmin()..denied = true),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Acesso restrito à administração da loja.'),
      findsOneWidget,
    );
    expect(find.text('NOVO PRODUTO'), findsNothing);
    expect(find.text('Vestido Aura'), findsNothing);
  });

  testWidgets(
    'admin creates product and category on a phone with correct price and stock',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeAdmin();
      await tester.pumpWidget(
        MaterialApp(home: AdminCatalogPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('NOVO PRODUTO'));
      await tester.enterText(
        find.byKey(const ValueKey('admin-name')),
        'Bolsa Lumen',
      );
      await tester.enterText(
        find.byKey(const ValueKey('admin-price')),
        '199,90',
      );
      await tester.enterText(find.byKey(const ValueKey('admin-stock')), '12');
      await tapVisible(tester, find.byTooltip('Nova categoria'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Acessórios',
      );
      await tapVisible(tester, find.text('CRIAR'));
      expect(repo.newCategory, 'Acessórios');
      await tapVisible(tester, find.text('SALVAR PRODUTO'));
      expect(repo.saved!['name'], 'Bolsa Lumen');
      expect(repo.saved!['price_cents'], 19990);
      expect(repo.saved!['stock'], 12);
      expect(repo.saved!['category_id'], 2);
      expect(repo.saved!.containsKey('version'), isFalse);
      expect(find.text('Produto salvo.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid price prevents a product write', (tester) async {
    final repo = FakeAdmin();
    await tester.pumpWidget(
      MaterialApp(home: AdminProductPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('admin-name')), 'Bolsa');
    await tester.enterText(find.byKey(const ValueKey('admin-price')), '1,999');
    await tapVisible(tester, find.text('SALVAR PRODUTO'));
    expect(repo.saves, 0);
    await tester.ensureVisible(find.byKey(const ValueKey('admin-price')));
    expect(
      find.text('Informe um preço positivo com até duas casas decimais.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'stock conflict blocks resubmission until the product is reloaded',
    (tester) async {
      final repo = FakeAdmin()..conflict = true;
      await tester.pumpWidget(
        MaterialApp(home: AdminCatalogPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Vestido Aura'));
      await tapVisible(tester, find.text('SALVAR PRODUTO'));
      expect(repo.saves, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'SALVAR PRODUTO'),
            )
            .onPressed,
        isNull,
      );
      repo.item = productData(version: 1, stock: 3);
      repo.conflict = false;
      await tapVisible(tester, find.text('RECARREGAR DADOS'));
      await tester.ensureVisible(find.byKey(const ValueKey('admin-stock')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('admin-stock')))
            .controller!
            .text,
        '3',
      );
      await tapVisible(tester, find.text('SALVAR PRODUTO'));
      expect(repo.saved!['version'], 1);
      expect(repo.saved!['stock'], 3);
      expect(tester.takeException(), isNull);
    },
  );
}
