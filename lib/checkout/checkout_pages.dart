import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'commerce_api.dart';
import '../store/store_layout.dart';

String errorText(Object error) => error is CommerceException
    ? error.message
    : 'Não foi possível completar a operação. Tente novamente.';

class RetryNotice extends StatelessWidget {
  const RetryNotice(this.message, this.retry, {super.key});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(message),
          TextButton(onPressed: retry, child: const Text('TENTAR NOVAMENTE')),
        ],
      ),
    ),
  );
}

class BagPage extends StatefulWidget {
  const BagPage({super.key, required this.repository});
  final CommerceRepository repository;
  @override
  State<BagPage> createState() => _BagPageState();
}

class _BagPageState extends State<BagPage> {
  CartSnapshot? _cart;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cart = await widget.repository.cart();
      if (mounted) setState(() => _cart = cart);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change(CartLine line, int quantity) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cart = await widget.repository.setQuantity(
        line.productId,
        quantity,
        _cart!.version,
      );
      if (mounted) setState(() => _cart = cart);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cart = _cart;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sua sacola'),
        actions: [
          IconButton(
            tooltip: 'Meus pedidos',
            onPressed: () => _open(OrdersPage(repository: widget.repository)),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) RetryNotice(_error!, _load),
            if (cart != null) ...[
              if (cart.activeOrderId != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Você tem uma compra aguardando pagamento.'),
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _open(
                                  OrderPage(
                                    orderId: cart.activeOrderId!,
                                    repository: widget.repository,
                                  ),
                                ),
                          child: const Text('RETOMAR PEDIDO'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (cart.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text(
                    'Sua sacola está vazia.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final line in cart.items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${money(line.unitPriceCents)} por unidade'),
                        if (!line.available ||
                            line.stock < line.quantity &&
                                cart.activeOrderId == null)
                          const Text(
                            'Quantidade indisponível. Ajuste sua sacola.',
                          ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Diminuir quantidade',
                              onPressed: _busy || cart.activeOrderId != null
                                  ? null
                                  : () => _change(line, line.quantity - 1),
                              icon: const Icon(Icons.remove),
                            ),
                            Text('${line.quantity}'),
                            IconButton(
                              tooltip: 'Aumentar quantidade',
                              onPressed:
                                  _busy ||
                                      cart.activeOrderId != null ||
                                      line.quantity >= line.stock
                                  ? null
                                  : () => _change(line, line.quantity + 1),
                              icon: const Icon(Icons.add),
                            ),
                            Expanded(
                              child: Text(
                                money(line.totalCents),
                                textAlign: TextAlign.end,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remover produto',
                              onPressed: _busy || cart.activeOrderId != null
                                  ? null
                                  : () => _change(line, 0),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Subtotal: ${money(cart.subtotalCents)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text('O valor da entrega aparece na revisão da compra.'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed:
                    _busy ||
                        _error != null ||
                        cart.items.isEmpty ||
                        cart.activeOrderId != null ||
                        cart.items.any(
                          (x) => !x.available || x.stock < x.quantity,
                        )
                    ? null
                    : () => _open(CheckoutPage(repository: widget.repository)),
                child: const Text('CONTINUAR COMPRA'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.repository});
  final CommerceRepository repository;
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'email',
      'document',
      'recipient',
      'postal_code',
      'street',
      'number',
      'complement',
      'district',
      'city',
      'state',
    ])
      key: TextEditingController(),
  };
  late String _key;
  Json? _attempt;
  CheckoutQuote? _quote;
  String? _shippingServiceId;
  bool _ratesCurrent = false;
  ShippingOption? get _shipping {
    if (!_ratesCurrent ||
        _quote?.postalCode !=
            value('postal_code').replaceAll(RegExp(r'\D'), '')) {
      return null;
    }
    for (final option in _quote?.shippingOptions ?? <ShippingOption>[]) {
      if (option.id == _shippingServiceId) return option;
    }
    return null;
  }

  int get _totalCents => _quote!.shippingRequired
      ? _quote!.cart.subtotalCents + (_shipping?.priceCents ?? 0)
      : _quote!.totalCents;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _newKey();
    _loadQuote();
  }

  void _newKey() => _key = List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuote({bool calculate = false}) async {
    final postalCode = value('postal_code').replaceAll(RegExp(r'\D'), '');
    if (calculate && !RegExp(r'^\d{8}$').hasMatch(postalCode)) {
      setState(
        () => _error = 'Informe os 8 números do CEP para calcular a entrega.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ratesCurrent = false;
      _shippingServiceId = null;
    });
    try {
      final quote = await widget.repository.quote(
        postalCode: calculate ? postalCode : null,
      );
      if (mounted) {
        setState(() {
          _quote = quote;
          _ratesCurrent = calculate;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String value(String key) => _fields[key]!.text.trim();
  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate() || _quote == null) return;
    if (_quote!.shippingRequired && _shipping == null) {
      setState(() => _error = 'Calcule o frete e selecione PAC ou SEDEX.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _attempt ??= {
      'cart_version': _quote!.cart.version,
      'expected_total_cents': _totalCents,
      if (_quote!.shippingRequired) ...{
        'shipping_quote_id': _quote!.shippingQuoteId,
        'shipping_service_id': _shipping!.id,
      },
      'payer_email': value('email'),
      'payer_document': value('document').replaceAll(RegExp(r'\D'), ''),
      'address': {
        for (final key in [
          'recipient',
          'street',
          'number',
          'complement',
          'district',
          'city',
        ])
          key: value(key),
        'postal_code': value('postal_code').replaceAll(RegExp(r'\D'), ''),
        'state': value('state').toUpperCase(),
      },
    };
    try {
      final order = await widget.repository.checkout(_attempt!, _key);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OrderPage(
            orderId: order.id,
            repository: widget.repository,
            generatePix: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is CommerceException && (e.status == 409 || e.status == 422)) {
        _attempt = null;
        _ratesCurrent = false;
        _shippingServiceId = null;
        _newKey();
        // A request whose response was lost may already have created the order.
        try {
          final cart = await widget.repository.cart();
          if (!mounted) return;
          if (cart.activeOrderId != null) {
            await Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => OrderPage(
                  orderId: cart.activeOrderId!,
                  repository: widget.repository,
                ),
              ),
            );
            return;
          }
          final quote = await widget.repository.quote();
          if (mounted) setState(() => _quote = quote);
        } catch (_) {
          /* Keep the original error and allow a fresh review. */
        }
      }
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget field(
    String key,
    String label, {
    TextInputType? keyboard,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey(key),
      controller: _fields[key],
      onChanged: key == 'postal_code'
          ? (_) => setState(() {
              _ratesCurrent = false;
              _shippingServiceId = null;
            })
          : null,
      enabled: !_busy && _attempt == null,
      keyboardType: keyboard,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (input) {
        final text = (input ?? '').trim();
        if (optional) return null;
        if (text.isEmpty) return 'Preencha este campo.';
        if (key == 'email' &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
          return 'Informe um e-mail válido.';
        }
        if (key == 'document' &&
            !validDocument(text.replaceAll(RegExp(r'\D'), ''))) {
          return 'Confira o CPF ou CNPJ.';
        }
        if (key == 'postal_code' &&
            text.replaceAll(RegExp(r'\D'), '').length != 8) {
          return 'Informe os 8 números do CEP.';
        }
        if (key == 'state' &&
            !const [
              'AC',
              'AL',
              'AP',
              'AM',
              'BA',
              'CE',
              'DF',
              'ES',
              'GO',
              'MA',
              'MT',
              'MS',
              'MG',
              'PA',
              'PB',
              'PR',
              'PE',
              'PI',
              'RJ',
              'RN',
              'RS',
              'RO',
              'RR',
              'SC',
              'SP',
              'SE',
              'TO',
            ].contains(text.toUpperCase())) {
          return 'Informe a UF, por exemplo SP.';
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Revisar compra')),
    body: StoreViewport(
      maxWidth: 760,
      child: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_quote == null && _error != null)
                RetryNotice(_error!, _loadQuote),
              if (_quote != null) ...[
                Text(
                  'Dados da pessoa pagadora',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                field('email', 'E-mail', keyboard: TextInputType.emailAddress),
                field(
                  'document',
                  'CPF ou CNPJ',
                  keyboard: TextInputType.number,
                ),
                const SizedBox(height: 8),
                Text(
                  'Endereço de entrega',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                field('recipient', 'Nome de quem recebe'),
                field('postal_code', 'CEP', keyboard: TextInputType.number),
                field('street', 'Rua'),
                field('number', 'Número'),
                field('complement', 'Complemento (opcional)', optional: true),
                field('district', 'Bairro'),
                field('city', 'Cidade'),
                field('state', 'Estado (UF)'),
                const Divider(),
                for (final line in _quote!.cart.items)
                  Text(
                    '${line.quantity} × ${line.name} — ${money(line.totalCents)}',
                  ),
                const SizedBox(height: 12),
                if (_quote!.shippingRequired) ...[
                  Text(
                    'Escolha sua entrega',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy || _attempt != null
                        ? null
                        : () => _loadQuote(calculate: true),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(
                      _busy ? 'CALCULANDO...' : 'CALCULAR PAC E SEDEX',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_ratesCurrent)
                    RadioGroup<String>(
                      groupValue: _shippingServiceId,
                      onChanged: (id) {
                        if (!_busy && _attempt == null) {
                          setState(() => _shippingServiceId = id);
                        }
                      },
                      child: Column(
                        children: [
                          for (final option in _quote!.shippingOptions)
                            Card(
                              child: RadioListTile<String>(
                                value: option.id,
                                enabled: !_busy && _attempt == null,
                                title: Text(
                                  '${option.label} — ${money(option.priceCents)}',
                                ),
                                subtitle: Text(
                                  'Até ${option.days} dias úteis após a postagem.',
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    const Text(
                      'Informe seu CEP e calcule as opções disponíveis.',
                    ),
                ] else ...[
                  Text(
                    '${_quote!.shippingLabel}: ${money(_quote!.shippingCents)}',
                  ),
                  Text(
                    'Prazo estimado: ${_quote!.shippingDays} dias úteis após aprovação.',
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '${_quote!.shippingRequired && _shipping == null ? 'Produtos (frete a calcular)' : 'Total'}: ${money(_totalCents)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_error!, key: const ValueKey('checkout-error')),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed:
                      _busy || (_quote!.shippingRequired && _shipping == null)
                      ? null
                      : _submit,
                  child: Text(
                    _attempt == null
                        ? 'CONFIRMAR E GERAR PIX'
                        : 'RETOMAR TENTATIVA',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

bool validDocument(String value) {
  if (!RegExp(r'^(\d{11}|\d{14})$').hasMatch(value) ||
      value.split('').toSet().length == 1) {
    return false;
  }
  final digits = value.split('').map(int.parse).toList();
  for (final size in value.length == 11 ? [9, 10] : [12, 13]) {
    final weights = value.length == 11
        ? List.generate(size, (i) => size + 1 - i)
        : (size == 12
              ? [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
              : [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
    var sum = 0;
    for (var i = 0; i < size; i++) {
      sum += digits[i] * weights[i];
    }
    final check = value.length == 11
        ? ((sum * 10) % 11) % 10
        : (sum % 11 < 2 ? 0 : 11 - sum % 11);
    if (digits[size] != check) return false;
  }
  return true;
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.repository});
  final CommerceRepository repository;
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late Future<List<StoreOrder>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.orders();
  }

  void _reload() => setState(() {
    _future = widget.repository.orders();
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Meus pedidos'),
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: FutureBuilder<List<StoreOrder>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return RetryNotice(errorText(snapshot.error!), _reload);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('Você ainda não tem pedidos.'));
        }
        return ListView(
          children: [
            for (final order in snapshot.data!)
              ListTile(
                title: Text(
                  'Pedido ${order.id.substring(0, 8)} — ${money(order.totalCents)}',
                ),
                subtitle: Text(order.statusLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => OrderPage(
                        orderId: order.id,
                        repository: widget.repository,
                      ),
                    ),
                  );
                  if (mounted) _reload();
                },
              ),
          ],
        );
      },
    ),
  );
}

class OrderPage extends StatefulWidget {
  const OrderPage({
    super.key,
    required this.orderId,
    required this.repository,
    this.generatePix = false,
  });
  final String orderId;
  final CommerceRepository repository;
  final bool generatePix;
  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> with WidgetsBindingObserver {
  StoreOrder? _order;
  String? _error;
  bool _busy = false;
  bool _foreground = true;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _operate(
      widget.generatePix ? widget.repository.pay : widget.repository.order,
    );
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_foreground &&
          !_busy &&
          _order?.pending == true &&
          _order?.payment != null &&
          ModalRoute.of(context)?.isCurrent == true) {
        _operate(widget.repository.refresh);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground &&
        !_busy &&
        _order?.pending == true &&
        _order?.payment != null) {
      _operate(widget.repository.refresh);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _operate(Future<StoreOrder> Function(String) action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await action(widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar este pedido?'),
        content: const Text(
          'Vamos conferir o pagamento antes de liberar os produtos da sua sacola.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('VOLTAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CANCELAR PEDIDO'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _operate(widget.repository.cancel);
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(title: const Text('Seu pedido')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              RetryNotice(_error!, () => _operate(widget.repository.order)),
            if (order != null) ...[
              Icon(
                order.paid ? Icons.check_circle : Icons.shopping_bag_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                order.statusLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                'Pedido ${order.id.substring(0, 8)}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              for (final item in order.items)
                Text(
                  '${item['quantity']} × ${item['name']} — ${money((item['unit_price_cents'] as int) * (item['quantity'] as int))}',
                ),
              Text('${order.shippingLabel}: ${money(order.shippingCents)}'),
              Text(
                'Total: ${money(order.totalCents)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Entrega: ${order.address['street']}, ${order.address['number']} — ${order.address['city']}/${order.address['state']}',
              ),
              const SizedBox(height: 24),
              if (order.pending) ...[
                if (order.payment == null)
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _operate(widget.repository.pay),
                    child: const Text('GERAR / RETOMAR PIX'),
                  )
                else ...[
                  if (order.nextAction['processing'] == true)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Seu PIX está sendo preparado. O código aparecerá aqui automaticamente.',
                      ),
                    ),
                  if (order.sandbox)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Pagamento de demonstração. Este código não pode ser pago no banco.',
                        ),
                      ),
                    ),
                  if (!order.sandbox &&
                      order.nextAction['qr_code_base64'] is String)
                    _PixImage(order.nextAction['qr_code_base64'] as String),
                  if (!order.sandbox &&
                      order.nextAction['copy_and_paste'] is String) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Copie o código ou leia o QR Code no aplicativo do seu banco.',
                    ),
                    SelectableText(
                      order.nextAction['copy_and_paste'] as String,
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: order.nextAction['copy_and_paste'] as String,
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Código PIX copiado.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('COPIAR PIX'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'O status é atualizado automaticamente. Você pode sair e retomar este pedido depois.',
                  ),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _operate(widget.repository.refresh),
                    child: const Text('VERIFICAR PAGAMENTO'),
                  ),
                ],
                TextButton(
                  onPressed: _busy ? null : _cancel,
                  child: const Text('CANCELAR PEDIDO'),
                ),
              ] else ...[
                if (order.paid)
                  const Text(
                    'Recebemos seu pagamento. Seu pedido está confirmado.',
                  ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('VOLTAR'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PixImage extends StatelessWidget {
  const _PixImage(this.encoded);
  final String encoded;
  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(
        encoded.contains(',') ? encoded.split(',').last : encoded,
      );
      return Center(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Image.memory(
            bytes,
            width: 220,
            height: 220,
            errorBuilder: (_, _, _) => const Text(
              'Use o código copia e cola.',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ),
      );
    } on FormatException {
      return const Text('QR Code indisponível. Use o código copia e cola.');
    }
  }
}
