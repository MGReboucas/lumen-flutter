import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:lumen_store/main.dart';

void main() {
  testWidgets('shows the Lumen entry and opens the storefront', (tester) async {
    await tester.pumpWidget(const LumenApp());
    expect(find.text('L U M E N'), findsOneWidget);

    await tester.tap(find.text('L U M E N'));
    await tester.pumpAndSettle();

    expect(find.text('Vestido Aura'), findsOneWidget);
    expect(find.text('R\$ 289,90'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_shopping_cart_rounded));
    await tester.pump();
    expect(find.text('Vestido Aura adicionado à sua sacola.'), findsOneWidget);
  });
}
