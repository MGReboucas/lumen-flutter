import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_store/checkout/checkout_pages.dart';

import 'checkout_test.dart' show FakeCommerce, cartJson;

void main() {
  for (final (width, scale) in [
    (320.0, 1.0),
    (390.0, 1.0),
    (768.0, 1.0),
    (1024.0, 1.0),
    (1920.0, 1.0),
    (320.0, 2.0),
    (1440.0, 2.0),
  ]) {
    testWidgets('bag stays usable at width $width and text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeCommerce();
      final data = cartJson();
      data['items'][0]['image_url'] = 'https://images.example.com/vestido.png';
      data['items'][0]['name'] =
          'Vestido Aura de cetim champagne com alças ajustáveis';
      api.data = data;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: BagPage(repository: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final items = tester.getRect(find.byKey(const ValueKey('bag-items')));
      if (find.byKey(const ValueKey('bag-summary')).evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('bag-summary')),
          180,
        );
        await tester.pumpAndSettle();
      }
      final offset = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      final summary = tester
          .getRect(find.byKey(const ValueKey('bag-summary')))
          .shift(Offset(0, offset));
      if (width >= 900 && scale == 1) {
        expect(summary.left, greaterThan(items.right));
        expect(summary.top, closeTo(items.top, 1));
      } else {
        expect(summary.top, greaterThanOrEqualTo(items.bottom));
      }
      expect(items.left, greaterThanOrEqualTo(16));
      expect(summary.right, lessThanOrEqualTo(width - 16));
      expect(summary.width, lessThanOrEqualTo(1052));
      if (width > 1100) {
        expect(items.left, greaterThanOrEqualTo((width - 1100) / 2));
      }
      for (final label in [
        'Diminuir quantidade',
        'Aumentar quantidade',
        'Remover produto',
      ]) {
        final control = find.byTooltip(label);
        if (control.evaluate().isEmpty) {
          await tester.scrollUntilVisible(control, -180);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(control);
        expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
      }
      await tester.scrollUntilVisible(find.text('CONTINUAR COMPRA'), 180);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('CONTINUAR COMPRA'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
