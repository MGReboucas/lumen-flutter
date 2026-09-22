import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_store/main.dart';
import 'package:lumen_store/store/store_pages.dart';

import 'account_pages_test.dart' show accountForTest;
import 'checkout_test.dart' show FakeCommerce;
import 'widget_test.dart' show FakeProductsRepository;

class _Products extends FakeProductsRepository {
  @override
  Future<List<StoreProduct>> listProducts({
    String? search,
    int? categoryId,
    int skip = 0,
    int limit = 20,
  }) async => [
    for (var i = 0; i < 4; i++)
      StoreProduct(
        id: i + 1,
        name: [
          'Vestido Aura',
          'Bolsa Aurora',
          'Bruma Lunar',
          'Óleo Iluminar',
        ][i],
        categoryName: 'Seleção Lumen',
        description: 'Uma escolha para iluminar seu dia.',
        price: 9.9,
        stock: 12,
      ),
  ];
}

void main() {
  for (final (size, columns, scale) in [
    (const Size(320, 740), 1, 1.0),
    (const Size(390, 844), 1, 1.0),
    (const Size(768, 1024), 2, 1.0),
    (const Size(1024, 768), 3, 1.0),
    (const Size(1440, 900), 4, 1.0),
    (const Size(1920, 1080), 4, 1.0),
    (const Size(390, 844), 1, 2.0),
    (const Size(1440, 900), 3, 2.0),
  ]) {
    testWidgets('store adapts to $size with text scale $scale', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = accountForTest();
      addTearDown(account.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: LumenHome(
            productsRepository: _Products(),
            commerceRepository: FakeCommerce(),
            accountController: account,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      Future<void> checkCards(String prefix) async {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('$prefix-product-1')),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final rects = [
          for (var id = 1; id <= 4; id++)
            tester.getRect(find.byKey(ValueKey('$prefix-product-$id'))),
        ];
        expect(
          rects.where((r) => (r.top - rects.first.top).abs() < 1).length,
          columns,
        );
        for (final rect in rects) {
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.width, lessThanOrEqualTo(500));
        }
        if (size.width > 1280) {
          expect(rects.first.left, closeTo((size.width - 1280) / 2 + 22, 1));
        }
        expect(tester.takeException(), isNull);
      }

      await checkCards('home');
      await tester.tap(find.text('Categorias'));
      await tester.pumpAndSettle();
      await checkCards('catalog');

      for (final product in await _Products().listProducts()) {
        await account.toggle(product);
      }
      await tester.tap(find.text('Favoritos'));
      await tester.pumpAndSettle();
      await checkCards('favorite');

      await tester.ensureVisible(find.text('Vestido Aura'));
      await tester.tap(find.text('Vestido Aura'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final image = tester.getRect(find.byType(ProductVisual));
      final title = tester.getRect(find.text('Vestido Aura'));
      if (size.width >= 1024) {
        expect(title.left, greaterThan(image.right));
      } else {
        expect(title.top, greaterThan(image.bottom));
      }
      await tester.ensureVisible(find.text('ADICIONAR À SACOLA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ADICIONAR À SACOLA'));
      await tester.pumpAndSettle();
      expect(
        find.text('Vestido Aura adicionado à sua sacola.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
