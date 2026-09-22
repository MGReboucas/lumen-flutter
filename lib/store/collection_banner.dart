import 'package:flutter/material.dart';

/// Campaign copy stays native so it wraps and scales independently of the photo.
class CollectionBanner extends StatelessWidget {
  const CollectionBanner({super.key, required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: const Color(0xFFF1E7D8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 860 &&
                MediaQuery.textScalerOf(context).scale(16) <= 22;
            final photo = Image.asset(
              'assets/images/collection-banner.png',
              semanticLabel:
                  'Vestido Aura, Bolsa Aurora, Bruma Lunar e Óleo Iluminar',
              fit: BoxFit.contain,
            );
            final copy = Padding(
              padding: EdgeInsets.all(wide ? 36 : 24),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Color(0xFF171717), fontSize: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 20,
                          color: Color(0xFF705523),
                        ),
                        Text(
                          'UM PRESENTE PARA VOCÊ',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Seus favoritos.\nFrete grátis.',
                      style: TextStyle(
                        fontSize: wide ? 42 : 32,
                        height: 1.08,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Escolha 2 ou mais produtos e deixe a entrega com a gente.',
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: onExplore,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF171717),
                        foregroundColor: const Color(0xFFF5DEA0),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      child: const Text(
                        'ESCOLHER MEUS FAVORITOS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Válido para 2 unidades ou mais, inclusive do mesmo produto. '
                      'PAC grátis onde disponível. Consulte seu CEP no checkout. '
                      'SEDEX cobrado à parte.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: Color(0xFF655B4D),
                      ),
                    ),
                  ],
                ),
              ),
            );
            return wide
                ? Row(
                    children: [
                      Expanded(flex: 5, child: copy),
                      Expanded(flex: 6, child: photo),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [photo, copy],
                  );
          },
        ),
      ),
    ),
  );
}
