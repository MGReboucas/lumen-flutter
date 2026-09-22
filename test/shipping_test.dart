import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_store/checkout/commerce_api.dart';
import 'package:lumen_store/checkout/checkout_pages.dart';

import 'checkout_test.dart' show FakeCommerce, cartJson, fillCheckout;

class ShippingCommerce extends FakeCommerce {
  final destinations = <String>[];
  bool unavailable = false;
  @override
  Future<CheckoutQuote> quote({String? postalCode}) async {
    if (postalCode != null) {
      destinations.add(postalCode);
      if (unavailable) {
        throw const CommerceException(
          'Entrega indisponível para este CEP.',
          422,
        );
      }
    }
    return CheckoutQuote.fromJson({
      ...cartJson(),
      'shipping_required': true,
      'shipping_cents': 0,
      'shipping_label': 'Entrega a calcular',
      'shipping_days': 0,
      'total_cents': 7980,
      'postal_code': postalCode,
      'shipping_quote_id': postalCode == null ? null : 'quote-for-$postalCode',
      'shipping_options': postalCode == null
          ? []
          : [
              {
                'id': '1',
                'label': 'Correios PAC',
                'price_cents': 1500,
                'days': 7,
              },
              {
                'id': '2',
                'label': 'Correios SEDEX',
                'price_cents': 2600,
                'days': 3,
              },
            ],
    });
  }
}

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'CEP recalculation and chosen shipping control checkout at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = ShippingCommerce();
        await tester.pumpWidget(
          MaterialApp(home: CheckoutPage(repository: api)),
        );
        await tester.pumpAndSettle();
        await fillCheckout(tester);
        FilledButton confirm() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'CONFIRMAR E GERAR PIX'),
        );
        expect(confirm().onPressed, isNull);
        await tester.ensureVisible(find.text('CALCULAR PAC E SEDEX'));
        await tester.tap(find.text('CALCULAR PAC E SEDEX'));
        await tester.pumpAndSettle();
        expect(api.destinations, ['01001000']);
        await tester.ensureVisible(find.text('Correios SEDEX — R\$ 26,00'));
        await tester.tap(find.text('Correios SEDEX — R\$ 26,00'));
        await tester.pumpAndSettle();
        expect(find.text('Total: R\$ 105,80'), findsOneWidget);
        expect(confirm().onPressed, isNotNull);
        // A new destination must never reuse the previous rates or total.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('postal_code')),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(
          find.byKey(const ValueKey('postal_code')),
          '59022-080',
        );
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('CONFIRMAR E GERAR PIX'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(confirm().onPressed, isNull);
        expect(find.text('Correios SEDEX — R\$ 26,00'), findsNothing);
        api.unavailable = true;
        await tester.ensureVisible(find.text('CALCULAR PAC E SEDEX'));
        await tester.tap(find.text('CALCULAR PAC E SEDEX'));
        await tester.pumpAndSettle();
        expect(
          find.text('Entrega indisponível para este CEP.'),
          findsOneWidget,
        );
        expect(confirm().onPressed, isNull);
        api.unavailable = false;
        await tester.ensureVisible(find.text('CALCULAR PAC E SEDEX'));
        await tester.tap(find.text('CALCULAR PAC E SEDEX'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Correios SEDEX — R\$ 26,00'));
        await tester.tap(find.text('Correios SEDEX — R\$ 26,00'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('CONFIRMAR E GERAR PIX'));
        await tester.tap(find.text('CONFIRMAR E GERAR PIX'));
        await tester.pumpAndSettle();
        expect(api.requests.single['expected_total_cents'], 10580);
        expect(api.requests.single['shipping_service_id'], '2');
        expect(api.requests.single['shipping_quote_id'], 'quote-for-59022080');
        expect(
          (api.requests.single['address'] as Json)['postal_code'],
          '59022080',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
