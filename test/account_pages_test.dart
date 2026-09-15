import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumen_store/main.dart';
import 'package:lumen_store/account/account_controller.dart';
import 'package:lumen_store/account/account_pages.dart';
import 'package:lumen_store/checkout/commerce_api.dart';

import 'checkout_test.dart' show MemoryStorage, FakeCommerce, cartJson;
import 'widget_test.dart' show FakeProductsRepository;

AccountController accountForTest({
  MemoryStorage? accountStorage,
  bool failLogin = false,
}) {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/cart')) {
      return http.Response(
        jsonEncode({'token': 'guest-token', 'cart': cartJson()}),
        201,
      );
    }
    if (request.url.path.endsWith('/register') ||
        request.url.path.endsWith('/login')) {
      if (failLogin) {
        return http.Response('{"detail":"E-mail ou senha incorretos."}', 401);
      }
      final body = jsonDecode(request.body) as Map;
      expect(body['password'], 'Minha frase segura 123!');
      return http.Response(
        jsonEncode({
          'access_token': 'account-token',
          'user': {'id': 1, 'email': body['email']},
        }),
        200,
      );
    }
    if (request.url.path.endsWith('/me')) {
      expect(request.headers['Authorization'], 'Bearer account-token');
      return http.Response('{"id":1,"email":"cliente@example.com"}', 200);
    }
    if (request.url.path.endsWith('/favorites')) {
      return http.Response('[]', 200);
    }
    if (request.url.path.endsWith('/logout')) return http.Response('', 204);
    return http.Response('{}', 404);
  });
  return AccountController(
    CommerceApi(
      client: client,
      storage: MemoryStorage(),
      accountStorage: accountStorage ?? MemoryStorage(),
    ),
    favoritesStorage: MemoryStorage(),
  );
}

void main() {
  testWidgets(
    'bottom navigation opens catalog favorites profile and product on phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = accountForTest();
      addTearDown(account.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: LumenHome(
            productsRepository: FakeProductsRepository(),
            commerceRepository: FakeCommerce(),
            accountController: account,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Categorias'));
      await tester.pumpAndSettle();
      expect(find.text('Encontre sua próxima escolha'), findsOneWidget);
      expect(find.text('Moda feminina'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('catalog-search')),
        'Vestido',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favoritar produto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favoritos'));
      await tester.pumpAndSettle();
      expect(find.text('Seus favoritos'), findsOneWidget);
      await tester.ensureVisible(find.text('Vestido Aura'));
      await tester.tap(find.text('Vestido Aura'));
      await tester.pumpAndSettle();
      expect(find.text('Detalhes do produto'), findsOneWidget);
      expect(find.text('Quantidade'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Seu espaço Lumen'), findsOneWidget);
      expect(find.text('CRIAR CONTA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'register validates confirmation then persists account and logs out',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = MemoryStorage();
      final account = accountForTest(accountStorage: saved);
      addTearDown(account.dispose);
      await account.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfilePage(account: account, onOrders: () {}),
          ),
        ),
      );
      await tester.tap(find.text('CRIAR CONTA'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'cliente@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'Minha frase segura 123!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm')),
        'diferente',
      );
      tester.testTextInput.hide();
      await tester.scrollUntilVisible(
        find.text('CADASTRAR'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('CADASTRAR'));
      await tester.pumpAndSettle();
      expect(account.user, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm')),
        'Minha frase segura 123!',
      );
      tester.testTextInput.hide();
      await tester.scrollUntilVisible(
        find.text('CADASTRAR'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('CADASTRAR'));
      await tester.pumpAndSettle();
      expect(find.text('cliente@example.com'), findsOneWidget);
      expect(saved.value, 'account-token');
      final resumed = accountForTest(accountStorage: saved);
      addTearDown(resumed.dispose);
      await resumed.initialize();
      expect(resumed.user!['email'], 'cliente@example.com');
      await tester.ensureVisible(find.text('SAIR DA CONTA'));
      await tester.tap(find.text('SAIR DA CONTA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAIR'));
      await tester.pumpAndSettle();
      expect(saved.value, '');
      expect(find.text('CRIAR CONTA'), findsOneWidget);
    },
  );

  testWidgets('login shows server error without authenticating', (
    tester,
  ) async {
    final account = accountForTest(failLogin: true);
    addTearDown(account.dispose);
    await tester.pumpWidget(MaterialApp(home: AuthPage(account: account)));
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'cliente@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'Minha frase segura 123!',
    );
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('ENTRAR'));
    await tester.tap(find.text('ENTRAR'));
    await tester.pumpAndSettle();
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(account.user, isNull);
  });
}
