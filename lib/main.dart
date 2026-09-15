import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'checkout/commerce_api.dart';
import 'checkout/checkout_pages.dart';

import 'store/catalog_api.dart';
import 'store/store_pages.dart';
import 'account/account_controller.dart';
import 'account/account_pages.dart';
export 'store/catalog_api.dart';

void main() => runApp(const LumenApp());

class LumenColors {
  static const ink = Color(0xFF171717);
  static const paper = Color(0xFFF7F2EA);
  static const gold = Color(0xFFD9B66A);
  static const goldLight = Color(0xFFF5DEA0);
  static const muted = Color(0xFFA7A097);
}

class LumenApp extends StatelessWidget {
  const LumenApp({
    super.key,
    this.productsRepository,
    this.commerceRepository,
    this.accountController,
  });

  final ProductsRepository? productsRepository;
  final CommerceRepository? commerceRepository;
  final AccountController? accountController;

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
      commerceRepository: commerceRepository ?? CommerceApi(),
      accountController: accountController,
    ),
  );
}

class LumenExperience extends StatefulWidget {
  const LumenExperience({
    super.key,
    required this.productsRepository,
    required this.commerceRepository,
    this.accountController,
  });

  final ProductsRepository productsRepository;
  final CommerceRepository commerceRepository;
  final AccountController? accountController;

  @override
  State<LumenExperience> createState() => _LumenExperienceState();
}

class _LumenExperienceState extends State<LumenExperience> {
  bool _showSplash = true;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  void _finishSplash() {
    _splashTimer?.cancel();
    setState(() => _showSplash = false);
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
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
        ? SplashScreen(key: const ValueKey('splash'), onFinish: _finishSplash)
        : LumenHome(
            key: const ValueKey('home'),
            productsRepository: widget.productsRepository,
            commerceRepository: widget.commerceRepository,
            accountController: widget.accountController,
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
    required this.commerceRepository,
    this.accountController,
  });

  final ProductsRepository productsRepository;
  final CommerceRepository commerceRepository;
  final AccountController? accountController;

  @override
  State<LumenHome> createState() => _LumenHomeState();
}

class _LumenHomeState extends State<LumenHome> {
  late final AccountController _account;
  int? _lastUserId;
  CartSnapshot? _cart;
  bool _cartBusy = false;
  int _selectedNav = 0;
  late Future<List<StoreProduct>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = widget.productsRepository.listProducts();
    _account =
        widget.accountController ??
        AccountController(
          widget.commerceRepository is CommerceApi
              ? widget.commerceRepository as CommerceApi
              : CommerceApi(),
        );
    _account.addListener(_accountChanged);
    _account.initialize();
    _refreshCart();
  }

  void _accountChanged() {
    if (!mounted) return;
    final userId = _account.user?['id'] as int?;
    if (userId != _lastUserId) {
      _lastUserId = userId;
      _cart = null;
      _refreshCart();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _account.removeListener(_accountChanged);
    if (widget.accountController == null) _account.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite(StoreProduct product) async {
    try {
      await _account.toggle(product);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(e))));
      }
    }
  }

  Future<void> _openProduct(StoreProduct product) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailPage(
          productId: product.id,
          repository: widget.productsRepository,
          account: _account,
          onAdd: (p, q) => _addToBag(p, count: q, propagate: true),
          onBag: _openBag,
        ),
      ),
    );
    if (mounted) {
      _refreshCart();
      _reloadProducts();
    }
  }

  void _reloadProducts() {
    setState(() {
      _productsFuture = widget.productsRepository.listProducts();
    });
  }

  Future<void> _addToBag(
    StoreProduct product, {
    int count = 1,
    bool propagate = false,
  }) async {
    if (_cartBusy) return;
    if (product.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este produto é demonstrativo. Aguarde o catálogo da loja.',
          ),
        ),
      );
      return;
    }
    setState(() => _cartBusy = true);
    try {
      final cart = await widget.commerceRepository.cart();
      final current = cart.items.where((line) => line.productId == product.id);
      final quantity = current.isEmpty ? count : current.first.quantity + count;
      final updated = await widget.commerceRepository.setQuantity(
        product.id,
        quantity,
        cart.version,
      );
      if (!mounted) return;
      setState(() => _cart = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} adicionado à sua sacola.')),
      );
    } catch (e) {
      if (propagate) rethrow;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(e))));
      }
    } finally {
      if (mounted) setState(() => _cartBusy = false);
    }
  }

  int get _bagCount => _cart?.count ?? 0;

  Future<void> _refreshCart() async {
    try {
      final cart = await widget.commerceRepository.cart();
      if (mounted) setState(() => _cart = cart);
    } catch (_) {
      // The bag screen presents retry details when opened.
    }
  }

  Future<void> _openBag() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BagPage(repository: widget.commerceRepository),
      ),
    );
    if (mounted) {
      _refreshCart();
      _reloadProducts();
    }
  }

  Future<void> _openOrders() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrdersPage(repository: widget.commerceRepository),
      ),
    );
    if (mounted) {
      _refreshCart();
      _reloadProducts();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: _selectedNav == 1
          ? CatalogPage(
              repository: widget.productsRepository,
              account: _account,
              onOpen: _openProduct,
              onAdd: _addToBag,
            )
          : _selectedNav == 2
          ? FavoritesPage(
              account: _account,
              onOpen: _openProduct,
              onAdd: _addToBag,
              onExplore: () => setState(() => _selectedNav = 1),
            )
          : _selectedNav == 3
          ? ProfilePage(account: _account, onOrders: _openOrders)
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                    child: Row(
                      children: [
                        const LumenWordmark(),
                        const Spacer(),
                        IconButton(
                          onPressed: _openOrders,
                          tooltip: 'Meus pedidos',
                          icon: const Icon(
                            Icons.receipt_long_outlined,
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: OutlinedButton(
                      onPressed: () => setState(() => _selectedNav = 1),
                      child: const Text('VER TODO O CATÁLOGO'),
                    ),
                  ),
                ),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (snapshot.hasError)
              _CatalogUnavailableNotice(onRetry: _reloadProducts),
            if (!snapshot.hasError && products.isEmpty)
              const Text(
                'Novidades em breve. Nosso catálogo está sendo preparado.',
              ),
            for (final product in products)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ProductCard(
                  product: product,
                  favorite: _account.isFavorite(product.id),
                  onFavorite: () => _toggleFavorite(product),
                  onAdd: () => _addToBag(product),
                  onOpen: () => _openProduct(product),
                ),
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

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.favorite,
    required this.onFavorite,
    required this.onAdd,
    required this.onOpen,
  });

  final StoreProduct product;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

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
                Positioned.fill(
                  child: InkWell(
                    onTap: onOpen,
                    child: ProductVisual(product: product),
                  ),
                ),
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
                  onPressed: product.stock > 0 ? onAdd : null,
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
                'Não foi possível conectar ao catálogo.',
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
