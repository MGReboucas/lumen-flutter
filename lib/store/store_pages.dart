import 'package:flutter/material.dart';

import '../account/account_controller.dart';
import '../checkout/checkout_pages.dart';
import 'catalog_api.dart';

class ProductVisual extends StatelessWidget {
  const ProductVisual({super.key, required this.product});
  final StoreProduct product;
  @override
  Widget build(BuildContext context) {
    final beauty = '${product.categoryName} ${product.name}'.toLowerCase();
    final icon = beauty.contains('bolsa')
        ? Icons.shopping_bag_outlined
        : beauty.contains('beleza') ||
              beauty.contains('bruma') ||
              beauty.contains('oleo')
        ? Icons.spa_outlined
        : Icons.checkroom;
    return Container(
      height: 210,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1E8D8), Color(0xFFCDB38C)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 90, color: const Color(0xFF866B48)),
          const SizedBox(height: 12),
          const Text(
            'L U M E N',
            style: TextStyle(color: Color(0xFF866B48), fontSize: 12),
          ),
          const Text(
            'Imagem ilustrativa',
            style: TextStyle(color: Color(0xFF756C62), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class CatalogTile extends StatelessWidget {
  const CatalogTile({
    super.key,
    required this.product,
    required this.account,
    required this.onOpen,
    required this.onAdd,
  });
  final StoreProduct product;
  final AccountController account;
  final VoidCallback onOpen, onAdd;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    margin: const EdgeInsets.only(bottom: 18),
    color: const Color(0xFFEEE4D6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            Semantics(
              button: true,
              label: 'Ver ${product.name}',
              child: InkWell(
                onTap: onOpen,
                child: ProductVisual(product: product),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: account.isFavorite(product.id)
                    ? 'Remover favorito'
                    : 'Favoritar produto',
                onPressed:
                    account.loading || account.updating.contains(product.id)
                    ? null
                    : () async {
                        try {
                          await account.toggle(product);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(errorText(e))),
                            );
                          }
                        }
                      },
                icon: Icon(
                  account.isFavorite(product.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: const Color(0xFF866B48),
                ),
              ),
            ),
          ],
        ),
        ListTile(
          onTap: onOpen,
          title: Text(
            product.name,
            style: const TextStyle(
              color: Color(0xFF171717),
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${product.formattedPrice}\n${product.stock > 0 ? product.shortDescription : 'Esgotado'}',
            style: const TextStyle(color: Color(0xFF756C62)),
          ),
          isThreeLine: true,
          trailing: IconButton(
            tooltip: 'Adicionar à sacola',
            onPressed: product.stock > 0 ? onAdd : null,
            icon: const Icon(Icons.add_shopping_cart, color: Color(0xFF171717)),
          ),
        ),
      ],
    ),
  );
}

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.repository,
    required this.account,
    required this.onOpen,
    required this.onAdd,
  });
  final ProductsRepository repository;
  final AccountController account;
  final ValueChanged<StoreProduct> onOpen, onAdd;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _search = TextEditingController();
  List<StoreCategory> _categories = [];
  List<StoreProduct> _products = [];
  int? _category;
  bool _busy = false, _more = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final categories = await widget.repository.categories();
      final products = await widget.repository.listProducts(
        search: _search.text.trim(),
        categoryId: _category,
        skip: append ? _products.length : 0,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _categories = categories;
        _products = append ? [..._products, ...products] : products;
        _more = products.length == 20;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = errorText(e));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      key: const PageStorageKey('catalog'),
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'Encontre sua próxima escolha',
          style: TextStyle(fontSize: 29),
        ),
        const SizedBox(height: 8),
        const Text(
          'Explore nossas categorias e descubra seus favoritos.',
          style: TextStyle(color: Color(0xFFA7A097)),
        ),
        const SizedBox(height: 22),
        TextField(
          key: const ValueKey('catalog-search'),
          controller: _search,
          onSubmitted: (_) => _load(),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar produtos',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Buscar',
              onPressed: () => _load(),
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tudo'),
              selected: _category == null,
              onSelected: (_) {
                setState(() => _category = null);
                _load();
              },
            ),
            for (final category in _categories)
              ChoiceChip(
                label: Text(category.name),
                selected: _category == category.id,
                onSelected: (_) {
                  setState(() => _category = category.id);
                  _load();
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) RetryNotice(_error!, () => _load()),
        if (!_busy && _error == null && _products.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Text(
              'Nenhum produto encontrado. Experimente outra busca.',
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 12),
        for (final product in _products)
          CatalogTile(
            product: product,
            account: widget.account,
            onOpen: () => widget.onOpen(product),
            onAdd: () => widget.onAdd(product),
          ),
        if (_more && _error == null)
          OutlinedButton(
            onPressed: _busy ? null : () => _load(append: true),
            child: const Text('CARREGAR MAIS'),
          ),
      ],
    ),
  );
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({
    super.key,
    required this.account,
    required this.onOpen,
    required this.onAdd,
    required this.onExplore,
  });
  final AccountController account;
  final ValueChanged<StoreProduct> onOpen, onAdd;
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const Text('Seus favoritos', style: TextStyle(fontSize: 30)),
      const SizedBox(height: 8),
      Text(
        account.user == null
            ? 'Salvos neste aparelho. Entre para ter favoritos na conta.'
            : 'Suas escolhas, salvas na sua conta.',
        style: const TextStyle(color: Color(0xFFA7A097)),
      ),
      const SizedBox(height: 24),
      if (account.loading)
        const LinearProgressIndicator()
      else if (account.error != null)
        RetryNotice(account.error!, account.initialize)
      else if (account.favorites.isEmpty) ...[
        const SizedBox(height: 40),
        const Icon(Icons.favorite_border, size: 64, color: Color(0xFFD9B66A)),
        const SizedBox(height: 20),
        const Text(
          'Ainda não tem favoritos por aqui.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onExplore,
          child: const Text('EXPLORAR CATÁLOGO'),
        ),
      ],
      for (final product in account.favorites)
        CatalogTile(
          product: product,
          account: account,
          onOpen: () => onOpen(product),
          onAdd: () => onAdd(product),
        ),
    ],
  );
}

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.productId,
    required this.repository,
    required this.account,
    required this.onAdd,
    required this.onBag,
  });
  final int productId;
  final ProductsRepository repository;
  final AccountController account;
  final Future<void> Function(StoreProduct, int) onAdd;
  final VoidCallback onBag;
  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Future<StoreProduct> _future;
  int _quantity = 1;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.product(widget.productId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalhes do produto'),
      actions: [
        IconButton(
          tooltip: 'Abrir sacola',
          onPressed: widget.onBag,
          icon: const Icon(Icons.shopping_bag_outlined),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.account,
      builder: (context, _) => FutureBuilder<StoreProduct>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return RetryNotice(
              errorText(snapshot.error!),
              () => setState(() {
                _future = widget.repository.product(widget.productId);
              }),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final product = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ProductVisual(product: product),
              ),
              const SizedBox(height: 24),
              Text(
                product.categoryName ?? 'Seleção Lumen',
                style: const TextStyle(color: Color(0xFFD9B66A)),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                product.formattedPrice,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              Text(product.description ?? 'Uma escolha da seleção Lumen.'),
              const SizedBox(height: 18),
              Text(
                product.stock > 0
                    ? '${product.stock} disponíveis'
                    : 'Produto esgotado',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Quantidade'),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Diminuir',
                    onPressed: _busy || _quantity <= 1
                        ? null
                        : () => setState(() => _quantity--),
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$_quantity'),
                  IconButton(
                    tooltip: 'Aumentar',
                    onPressed:
                        _busy || _quantity >= product.stock || _quantity >= 99
                        ? null
                        : () => setState(() => _quantity++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text(_busy ? 'ADICIONANDO...' : 'ADICIONAR À SACOLA'),
                onPressed: _busy || product.stock == 0
                    ? null
                    : () async {
                        setState(() {
                          _busy = true;
                          _error = null;
                        });
                        try {
                          await widget.onAdd(product, _quantity);
                        } catch (e) {
                          if (mounted) setState(() => _error = errorText(e));
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),
              OutlinedButton.icon(
                onPressed:
                    widget.account.loading ||
                        widget.account.updating.contains(product.id)
                    ? null
                    : () async {
                        try {
                          await widget.account.toggle(product);
                        } catch (e) {
                          if (mounted) setState(() => _error = errorText(e));
                        }
                      },
                icon: Icon(
                  widget.account.isFavorite(product.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                label: Text(
                  widget.account.isFavorite(product.id)
                      ? 'REMOVER DOS FAVORITOS'
                      : 'SALVAR NOS FAVORITOS',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Frete e prazo são apresentados na revisão da compra. Pagamento por PIX.',
              ),
            ],
          );
        },
      ),
    ),
  );
}
