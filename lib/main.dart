import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const LumenApp());

class LumenColors {
  static const ink = Color(0xFF171717);
  static const paper = Color(0xFFF7F2EA);
  static const gold = Color(0xFFD9B66A);
  static const goldLight = Color(0xFFF5DEA0);
  static const muted = Color(0xFFA7A097);
}

class LumenApp extends StatelessWidget {
  const LumenApp({super.key, this.productsRepository, this.paymentRepository});

  final ProductsRepository? productsRepository;
  final PaymentRepository? paymentRepository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lumen',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: LumenColors.ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: LumenColors.gold,
        brightness: Brightness.dark,
        surface: LumenColors.ink,
      ),
    ),
    home: LumenExperience(
      productsRepository: productsRepository ?? ProductApi(),
      paymentRepository: paymentRepository ?? PaymentApi(),
    ),
  );
}

class LumenExperience extends StatefulWidget {
  const LumenExperience({
    super.key,
    required this.productsRepository,
    required this.paymentRepository,
  });

  final ProductsRepository productsRepository;
  final PaymentRepository paymentRepository;

  @override
  State<LumenExperience> createState() => _LumenExperienceState();
}

class _LumenExperienceState extends State<LumenExperience> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 650),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .03),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: _showSplash
        ? SplashScreen(
            key: const ValueKey('splash'),
            onFinish: () => setState(() => _showSplash = false),
          )
        : LumenHome(
            key: const ValueKey('home'),
            productsRepository: widget.productsRepository,
            paymentRepository: widget.paymentRepository,
          ),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return Scaffold(
      body: InkWell(
        onTap: widget.onFinish,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.1, -.35),
              radius: 1.15,
              colors: [Color(0xFF30302D), LumenColors.ink],
            ),
          ),
          child: Center(
            child: FadeTransition(
              opacity: curve,
              child: ScaleTransition(
                scale: Tween<double>(begin: .88, end: 1).animate(curve),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LumenMark(size: 140),
                    SizedBox(height: 18),
                    Text(
                      'L U M E N',
                      style: TextStyle(
                        color: LumenColors.goldLight,
                        fontSize: 29,
                        letterSpacing: 9,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    SizedBox(height: 42),
                    _Tagline(),
                    SizedBox(height: 32),
                    Text(
                      'toque para entrar',
                      style: TextStyle(
                        color: LumenColors.muted,
                        fontSize: 11,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: const [
      SizedBox(
        width: 66,
        child: Divider(color: LumenColors.gold, thickness: .6),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Icon(Icons.star_rounded, color: LumenColors.gold, size: 17),
      ),
      SizedBox(
        width: 66,
        child: Divider(color: LumenColors.gold, thickness: .6),
      ),
    ],
  );
}

class LumenHome extends StatefulWidget {
  const LumenHome({
    super.key,
    required this.productsRepository,
    required this.paymentRepository,
  });

  final ProductsRepository productsRepository;
  final PaymentRepository paymentRepository;

  @override
  State<LumenHome> createState() => _LumenHomeState();
}

class _LumenHomeState extends State<LumenHome> {
  bool _favorite = false;
  final Map<int, BagItem> _bag = {};
  int _selectedNav = 0;
  late Future<List<StoreProduct>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = widget.productsRepository.listProducts();
  }

  void _reloadProducts() {
    setState(() => _productsFuture = widget.productsRepository.listProducts());
  }

  void _addToBag(StoreProduct product) {
    setState(() {
      final current = _bag[product.id];
      _bag[product.id] = BagItem(
        product: product,
        quantity: (current?.quantity ?? 0) + 1,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} adicionado à sua sacola.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  int get _bagCount =>
      _bag.values.fold(0, (total, item) => total + item.quantity);

  Future<void> _openBag() async {
    if (_bag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sua sacola ainda está vazia.')),
      );
      return;
    }
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BagPage(
          items: _bag.values.toList(growable: false),
          paymentRepository: widget.paymentRepository,
        ),
      ),
    );
    if (paid == true && mounted) setState(_bag.clear);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Row(
                children: [
                  const LumenWordmark(),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.search_rounded,
                      color: LumenColors.paper,
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: _openBag,
                        icon: const Icon(
                          Icons.shopping_bag_outlined,
                          color: LumenColors.paper,
                        ),
                      ),
                      if (_bagCount > 0)
                        Positioned(
                          top: 3,
                          right: 4,
                          child: CircleAvatar(
                            radius: 8,
                            backgroundColor: LumenColors.gold,
                            child: Text(
                              '$_bagCount',
                              style: const TextStyle(
                                color: LumenColors.ink,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
          const SliverToBoxAdapter(child: _HomeHero()),
          const SliverToBoxAdapter(child: SizedBox(height: 25)),
          SliverToBoxAdapter(child: _buildProductShowcase()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: _SectionHeading()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      height: 70,
      backgroundColor: const Color(0xFF20201E),
      indicatorColor: const Color(0x22D9B66A),
      selectedIndex: _selectedNav,
      onDestinationSelected: (value) => setState(() => _selectedNav = value),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 10, color: LumenColors.paper),
      ),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Início',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Categorias',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_border_rounded),
          selectedIcon: Icon(Icons.favorite_rounded),
          label: 'Favoritos',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Perfil',
        ),
      ],
    ),
  );

  Widget _buildProductShowcase() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    child: FutureBuilder<List<StoreProduct>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingProductCard();
        }

        final products = snapshot.data ?? const [];
        final isDemoMode = snapshot.hasError || products.isEmpty;
        final product = isDemoMode ? lumenDemoProduct : products.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isDemoMode) _CatalogUnavailableNotice(onRetry: _reloadProducts),
            ProductCard(
              product: product,
              favorite: _favorite,
              onFavorite: () => setState(() => _favorite = !_favorite),
              onAdd: () => _addToBag(product),
            ),
          ],
        );
      },
    ),
  );
}

class _HomeHero extends StatelessWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOVA COLEÇÃO',
          style: TextStyle(
            color: LumenColors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.1,
          ),
        ),
        SizedBox(height: 9),
        Text(
          'Vista a sua\nessência.',
          style: TextStyle(
            color: LumenColors.paper,
            fontSize: 38,
            height: 1.03,
            fontWeight: FontWeight.w300,
            letterSpacing: -.8,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Peças escolhidas para iluminar o seu dia.',
          style: TextStyle(color: LumenColors.muted, fontSize: 14),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 22),
    child: Row(
      children: [
        Text(
          'Escolhidos para você',
          style: TextStyle(
            color: LumenColors.paper,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        Spacer(),
        Text(
          'VER TUDO',
          style: TextStyle(
            color: LumenColors.gold,
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.favorite,
    required this.onFavorite,
    required this.onAdd,
  });

  final StoreProduct product;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFEEE4D6)),
      child: Column(
        children: [
          SizedBox(
            height: 270,
            child: Stack(
              children: [
                const Positioned.fill(child: FashionIllustration()),
                Positioned(
                  top: 15,
                  left: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: LumenColors.ink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'EXCLUSIVO',
                      style: TextStyle(
                        color: LumenColors.goldLight,
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 8,
                  child: IconButton(
                    onPressed: onFavorite,
                    icon: Icon(
                      favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: favorite
                          ? const Color(0xFFAF4C55)
                          : LumenColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 17),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          color: LumenColors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        product.shortDescription,
                        style: TextStyle(
                          color: Color(0xFF756C62),
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 9),
                      Text(
                        product.formattedPrice,
                        style: TextStyle(
                          color: LumenColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: LumenColors.ink,
                    foregroundColor: LumenColors.goldLight,
                    padding: const EdgeInsets.all(15),
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _LoadingProductCard extends StatelessWidget {
  const _LoadingProductCard();

  @override
  Widget build(BuildContext context) => Container(
    height: 400,
    decoration: BoxDecoration(
      color: const Color(0xFF242421),
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              color: LumenColors.gold,
              strokeWidth: 2,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Preparando a seleção Lumen...',
            style: TextStyle(color: LumenColors.muted, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}

class _CatalogUnavailableNotice extends StatelessWidget {
  const _CatalogUnavailableNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x55756449)),
        borderRadius: BorderRadius.circular(14),
        color: const Color(0x33242421),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: LumenColors.gold,
              size: 18,
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'Exibindo a seleção demonstrativa.',
                style: TextStyle(color: LumenColors.paper, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'TENTAR',
                style: TextStyle(fontSize: 10, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    this.categoryName,
  });

  final int id;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final String? categoryName;

  factory StoreProduct.fromJson(Map<String, dynamic> json) => StoreProduct(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    price: (json['price'] as num).toDouble(),
    stock: json['stock'] as int,
    categoryName: json['category_name'] as String?,
  );

  String get shortDescription => categoryName ?? description ?? 'Seleção Lumen';

  String get formattedPrice =>
      'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
}

const lumenDemoProduct = StoreProduct(
  id: 0,
  name: 'Vestido Aura',
  description: 'Cetim champagne · edição limitada',
  price: 289.90,
  stock: 12,
  categoryName: 'Coleção Vista sua essência',
);

abstract class ProductsRepository {
  Future<List<StoreProduct>> listProducts();
}

class ProductApi implements ProductsRepository {
  ProductApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:8000/api/v1',
          );

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<List<StoreProduct>> listProducts() async {
    final response = await _client
        .get(
          Uri.parse('${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}/products'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw ProductApiException('Não foi possível carregar o catálogo.');
    }

    final payload = jsonDecode(response.body);
    if (payload is! List) {
      throw ProductApiException('Resposta de catálogo inválida.');
    }

    return payload
        .whereType<Map<String, dynamic>>()
        .map(StoreProduct.fromJson)
        .where((product) => product.stock > 0)
        .toList();
  }
}

class ProductApiException implements Exception {
  ProductApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BagItem {
  const BagItem({required this.product, required this.quantity});

  final StoreProduct product;
  final int quantity;

  double get total => product.price * quantity;
}

class PaymentCharge {
  const PaymentCharge({
    required this.providerChargeId,
    required this.status,
    this.copyAndPaste,
    this.qrCodeBase64,
    this.ticketUrl,
  });

  final String providerChargeId;
  final String status;
  final String? copyAndPaste;
  final String? qrCodeBase64;
  final String? ticketUrl;

  bool get isPaid => status == 'paid';

  factory PaymentCharge.fromJson(Map<String, dynamic> json) {
    final nextAction = json['next_action'] as Map<String, dynamic>? ?? const {};
    return PaymentCharge(
      providerChargeId: json['provider_charge_id'] as String,
      status: json['status'] as String,
      copyAndPaste: nextAction['copy_and_paste'] as String?,
      qrCodeBase64: nextAction['qr_code_base64'] as String?,
      ticketUrl: nextAction['ticket_url'] as String?,
    );
  }
}

abstract class PaymentRepository {
  Future<PaymentCharge> createPix({
    required String orderReference,
    required double amount,
    required String email,
    required String document,
    required String idempotencyKey,
  });

  Future<PaymentCharge> getCharge(String providerChargeId);
}

class PaymentApi implements PaymentRepository {
  PaymentApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:8000/api/v1',
          );

  final http.Client _client;
  final String _baseUrl;

  String get _paymentsUrl =>
      '${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}/payments';

  @override
  Future<PaymentCharge> createPix({
    required String orderReference,
    required double amount,
    required String email,
    required String document,
    required String idempotencyKey,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_paymentsUrl/charges'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Idempotency-Key': idempotencyKey,
          },
          body: jsonEncode({
            'order_reference': orderReference,
            'amount': amount.toStringAsFixed(2),
            'method': 'pix',
            'payer_email': email,
            'payer_document': document,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _parseCharge(response);
  }

  @override
  Future<PaymentCharge> getCharge(String providerChargeId) async {
    final response = await _client
        .get(
          Uri.parse('$_paymentsUrl/charges/$providerChargeId'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));
    return _parseCharge(response);
  }

  PaymentCharge _parseCharge(http.Response response) {
    final payload = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = payload is Map<String, dynamic> ? payload['detail'] : null;
      throw PaymentApiException(detail as String? ?? 'Não foi possível criar o PIX.');
    }
    if (payload is! Map<String, dynamic>) {
      throw PaymentApiException('Resposta de pagamento inválida.');
    }
    return PaymentCharge.fromJson(payload);
  }
}

class PaymentApiException implements Exception {
  PaymentApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BagPage extends StatelessWidget {
  const BagPage({super.key, required this.items, required this.paymentRepository});

  final List<BagItem> items;
  final PaymentRepository paymentRepository;

  double get _total => items.fold(0, (total, item) => total + item.total);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: LumenColors.ink,
      foregroundColor: LumenColors.paper,
      title: const Text('Sua sacola'),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(color: Color(0x334F4B45)),
                itemBuilder: (_, index) {
                  final item = items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.product.name),
                    subtitle: Text('${item.quantity} item${item.quantity > 1 ? 's' : ''}'),
                    trailing: Text(item.product.formattedPrice),
                  );
                },
              ),
            ),
            const Divider(color: LumenColors.gold),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 18)),
                Text(
                  'R\$ ${_total.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                final paid = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => PixCheckoutPage(
                      total: _total,
                      paymentRepository: paymentRepository,
                    ),
                  ),
                );
                if (paid == true && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              icon: const Icon(Icons.pix_rounded),
              label: const Text('PAGAR COM PIX'),
              style: FilledButton.styleFrom(
                backgroundColor: LumenColors.gold,
                foregroundColor: LumenColors.ink,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PixCheckoutPage extends StatefulWidget {
  const PixCheckoutPage({super.key, required this.total, required this.paymentRepository});

  final double total;
  final PaymentRepository paymentRepository;

  @override
  State<PixCheckoutPage> createState() => _PixCheckoutPageState();
}

class _PixCheckoutPageState extends State<PixCheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _documentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  Future<void> _generatePix() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final orderReference = 'LUMEN-${DateTime.now().microsecondsSinceEpoch}';
    try {
      final charge = await widget.paymentRepository.createPix(
        orderReference: orderReference,
        amount: widget.total,
        email: _emailController.text.trim(),
        document: _documentController.text.replaceAll(RegExp(r'\D'), ''),
        idempotencyKey: 'pix-$orderReference',
      );
      if (!mounted) return;
      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PixPaymentPage(
            charge: charge,
            paymentRepository: widget.paymentRepository,
          ),
        ),
      );
      if (paid == true && mounted) Navigator.of(context).pop(true);
    } on PaymentApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } on http.ClientException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível conectar ao pagamento.')),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A conexão demorou. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: LumenColors.ink,
      foregroundColor: LumenColors.paper,
      title: const Text('Pagamento PIX'),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              'R\$ ${widget.total.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(fontSize: 34, color: LumenColors.gold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Informe os dados da pessoa pagadora para gerar o PIX.'),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
              validator: (value) => value != null && value.contains('@') ? null : 'Informe um e-mail válido.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _documentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'CPF ou CNPJ'),
              validator: (value) {
                final document = (value ?? '').replaceAll(RegExp(r'\D'), '');
                return document.length == 11 || document.length == 14 ? null : 'Informe CPF ou CNPJ válido.';
              },
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _generatePix,
              style: FilledButton.styleFrom(
                backgroundColor: LumenColors.gold,
                foregroundColor: LumenColors.ink,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('GERAR PIX'),
            ),
          ],
        ),
      ),
    ),
  );
}

class PixPaymentPage extends StatefulWidget {
  const PixPaymentPage({super.key, required this.charge, required this.paymentRepository});

  final PaymentCharge charge;
  final PaymentRepository paymentRepository;

  @override
  State<PixPaymentPage> createState() => _PixPaymentPageState();
}

class _PixPaymentPageState extends State<PixPaymentPage> {
  late PaymentCharge _charge;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _charge = widget.charge;
  }

  Future<void> _refreshStatus() async {
    setState(() => _refreshing = true);
    try {
      final updated = await widget.paymentRepository.getCharge(_charge.providerChargeId);
      if (mounted) setState(() => _charge = updated);
    } on PaymentApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } on http.ClientException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível conectar ao pagamento.')),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível consultar o pagamento agora.')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Uint8List? get _qrBytes {
    final encoded = _charge.qrCodeBase64;
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded.contains(',') ? encoded.split(',').last : encoded);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = _charge.isPaid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: LumenColors.ink,
        foregroundColor: LumenColors.paper,
        title: const Text('Pague com PIX'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Icon(paid ? Icons.check_circle_rounded : Icons.pix_rounded, color: LumenColors.gold, size: 58),
            const SizedBox(height: 14),
            Text(
              paid ? 'Pagamento aprovado' : 'Escaneie o QR Code',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (!paid && _qrBytes != null)
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Image.memory(_qrBytes!, width: 220, height: 220),
                ),
              ),
            if (!paid) ...[
              const SizedBox(height: 24),
              const Text('Ou copie o código PIX:'),
              const SizedBox(height: 8),
              SelectableText(_charge.copyAndPaste ?? 'Código PIX indisponível.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _charge.copyAndPaste == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: _charge.copyAndPaste!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Código PIX copiado.')),
                          );
                        }
                      },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('COPIAR CÓDIGO'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _refreshing ? null : _refreshStatus,
                child: _refreshing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('JÁ FIZ O PAGAMENTO'),
              ),
            ] else
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: LumenColors.gold, foregroundColor: LumenColors.ink),
                child: const Text('CONCLUIR PEDIDO'),
              ),
          ],
        ),
      ),
    );
  }
}

class FashionIllustration extends StatelessWidget {
  const FashionIllustration({super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DressPainter(), child: const SizedBox.expand());
}

class _DressPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backdrop = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEEE7DB), Color(0xFFD2B58D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, backdrop);
    final glow = Paint()..color = Colors.white.withValues(alpha: .36);
    canvas.drawCircle(Offset(size.width * .76, size.height * .2), 70, glow);
    final dress = Paint()..color = const Color(0xFF92724D);
    final path = Path()
      ..moveTo(size.width * .48, 36)
      ..lineTo(size.width * .57, 36)
      ..lineTo(size.width * .60, 100)
      ..lineTo(size.width * .82, size.height - 16)
      ..quadraticBezierTo(
        size.width * .52,
        size.height + 9,
        size.width * .20,
        size.height - 16,
      )
      ..lineTo(size.width * .43, 100)
      ..close();
    canvas.drawPath(path, dress);
    final waist = Paint()..color = const Color(0xFF725536);
    canvas.drawRect(
      Rect.fromLTWH(size.width * .405, 98, size.width * .2, 7),
      waist,
    );
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .45)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * .49, 47),
      Offset(size.width * .50, size.height - 20),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LumenMark extends StatelessWidget {
  const LumenMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: size,
    width: size * 1.35,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(size: Size(size * 1.35, size), painter: _MarkPainter()),
        Positioned(
          top: 0,
          child: Text(
            'L',
            style: TextStyle(
              fontFamily: 'serif',
              color: LumenColors.goldLight,
              height: .88,
              fontSize: size * .99,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LumenColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final curve = Path()
      ..moveTo(size.width * .08, size.height * .68)
      ..cubicTo(
        size.width * .10,
        size.height * .42,
        size.width * .34,
        size.height * .56,
        size.width * .39,
        size.height * .69,
      )
      ..cubicTo(
        size.width * .65,
        size.height * .49,
        size.width * .79,
        size.height * .74,
        size.width * .90,
        size.height * .73,
      )
      ..cubicTo(
        size.width * .97,
        size.height * .73,
        size.width * .98,
        size.height * .64,
        size.width * .91,
        size.height * .61,
      );
    canvas.drawPath(curve, paint);
    final star = Paint()..color = LumenColors.goldLight;
    final center = Offset(size.width * .91, size.height * .28);
    final starPath = Path();
    for (var i = 0; i < 8; i++) {
      final radius = i.isEven ? 9.0 : 2.6;
      final angle = i * math.pi / 4 - math.pi / 2;
      final point =
          center + Offset(radius * math.cos(angle), radius * math.sin(angle));
      if (i == 0) {
        starPath.moveTo(point.dx, point.dy);
      } else {
        starPath.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(starPath..close(), star);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LumenWordmark extends StatelessWidget {
  const LumenWordmark({super.key});

  @override
  Widget build(BuildContext context) => const Text(
    'LUMEN',
    style: TextStyle(
      color: LumenColors.goldLight,
      fontSize: 19,
      letterSpacing: 4.2,
      fontWeight: FontWeight.w300,
    ),
  );
}
