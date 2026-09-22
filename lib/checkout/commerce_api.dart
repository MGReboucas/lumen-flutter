import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';

typedef Json = Map<String, dynamic>;

String money(int cents) =>
    'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';

class CommerceException implements Exception {
  const CommerceException(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

abstract class SessionStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage(String baseUrl, {String scope = 'cart'})
    : _key = 'lumen.$scope.${Uri.encodeComponent(baseUrl)}';
  final String _key;
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

class CartLine {
  CartLine.fromJson(Json json)
    : productId = json['product_id'] as int,
      name = json['name'] as String,
      quantity = json['quantity'] as int,
      unitPriceCents = json['unit_price_cents'] as int,
      stock = json['stock'] as int,
      available = json['available'] as bool;
  final int productId, quantity, unitPriceCents, stock;
  final String name;
  final bool available;
  int get totalCents => unitPriceCents * quantity;
}

class CartSnapshot {
  CartSnapshot.fromJson(Json json)
    : version = json['version'] as int,
      items = (json['items'] as List)
          .map((x) => CartLine.fromJson(x as Json))
          .toList(),
      subtotalCents = json['subtotal_cents'] as int,
      activeOrderId = json['active_order_id'] as String?;
  final int version, subtotalCents;
  final List<CartLine> items;
  final String? activeOrderId;
  int get count => items.fold(0, (a, x) => a + x.quantity);
}

class CheckoutQuote {
  CheckoutQuote.fromJson(Json json)
    : cart = CartSnapshot.fromJson(json),
      shippingCents = json['shipping_cents'] as int,
      totalCents = json['total_cents'] as int,
      shippingLabel = json['shipping_label'] as String,
      shippingDays = json['shipping_days'] as int;
  final CartSnapshot cart;
  final int shippingCents, totalCents, shippingDays;
  final String shippingLabel;
}

class StoreOrder {
  StoreOrder.fromJson(Json json)
    : id = json['id'] as String,
      status = json['status'] as String,
      totalCents = json['total_cents'] as int,
      subtotalCents = json['subtotal_cents'] as int,
      shippingCents = json['shipping_cents'] as int,
      shippingLabel = json['shipping_label'] as String,
      items = (json['items'] as List).cast<Json>(),
      address = json['address'] as Json,
      payment = json['payment'] as Json?,
      createdAt = DateTime.parse(_utc(json['created_at'] as String)),
      expiresAt = DateTime.parse(_utc(json['expires_at'] as String));
  static String _utc(String value) =>
      RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value) ? value : '${value}Z';
  final String id, status, shippingLabel;
  final int totalCents, subtotalCents, shippingCents;
  final List<Json> items;
  final Json address;
  final Json? payment;
  final DateTime createdAt, expiresAt;
  bool get pending => status == 'awaiting_payment';
  bool get paid => status == 'paid';
  bool get sandbox => payment?['provider'] == 'sandbox';
  Json get nextAction => payment?['next_action'] as Json? ?? {};
  String get statusLabel => switch (status) {
    'awaiting_payment' => 'Aguardando pagamento',
    'paid' => 'Pagamento aprovado',
    'cancelled' => 'Pedido cancelado',
    'failed' => 'Pagamento recusado',
    'refunded' => 'Pagamento reembolsado',
    'review_required' => 'Pagamento em análise pela loja',
    _ => 'Pedido em processamento',
  };
}

abstract class CommerceRepository {
  Future<CartSnapshot> cart();
  Future<CartSnapshot> setQuantity(int productId, int quantity, int version);
  Future<CheckoutQuote> quote();
  Future<StoreOrder> checkout(Json request, String idempotencyKey);
  Future<List<StoreOrder>> orders();
  Future<StoreOrder> order(String id);
  Future<StoreOrder> pay(String id);
  Future<StoreOrder> refresh(String id);
  Future<StoreOrder> cancel(String id);
}

class CommerceApi implements CommerceRepository {
  CommerceApi({
    http.Client? client,
    String? baseUrl,
    SessionStorage? storage,
    SessionStorage? accountStorage,
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(RegExp(r'/+$'), ''),
       _storage = storage ?? SecureSessionStorage(baseUrl ?? defaultBaseUrl),
       _accountStorage =
           accountStorage ??
           SecureSessionStorage(baseUrl ?? defaultBaseUrl, scope: 'account');
  static String get defaultBaseUrl => apiBaseUrl;
  final http.Client _client;
  final String _baseUrl;
  final SessionStorage _storage;
  final SessionStorage _accountStorage;
  String? _accountToken;
  Future<void>? _loadingAccount;
  String? _token;
  Future<void>? _initializing;

  Future<void> _initialize() async {
    if (_token != null) return;
    return _initializing ??= _loadSession().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _loadSession() async {
    final stored = await _storage.read();
    if (stored != null && stored.isNotEmpty) {
      _token = stored;
      return;
    }
    final response = await _send('POST', '/cart', authenticated: false) as Json;
    final token = response['token'] as String;
    await _storage.write(token);
    _token = token;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Json? body,
    String? key,
    bool authenticated = true,
    String? guestToken,
  }) async {
    try {
      if (authenticated) {
        await loadAccount();
        if (_accountToken == null) await _initialize();
      }
      final request = http.Request(method, Uri.parse('$_baseUrl$path'));
      request.headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (authenticated && _accountToken != null)
          'Authorization': 'Bearer $_accountToken',
        if (authenticated && _accountToken == null) 'X-Cart-Token': _token!,
        'X-Cart-Token': ?guestToken,
        'Idempotency-Key': ?key,
      });
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(const Duration(seconds: 35));
      dynamic payload;
      if (response.statusCode == 204) return null;
      try {
        payload = jsonDecode(response.body);
      } on FormatException {
        throw const CommerceException(
          'A loja retornou uma resposta inválida. Tente novamente.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = payload is Map ? payload['detail'] : null;
        throw CommerceException(
          detail is String ? detail : 'Confira os dados e tente novamente.',
          response.statusCode,
        );
      }
      return payload;
    } on TimeoutException {
      throw const CommerceException(
        'A conexão demorou. Retome o mesmo pedido para conferir o resultado.',
      );
    } on http.ClientException {
      throw const CommerceException(
        'Sem conexão com a loja. Confira sua internet e tente novamente.',
      );
    }
  }

  Future<void> loadAccount() => _loadingAccount ??=
      (() async {
        final saved = await _accountStorage.read();
        _accountToken = saved == null || saved.isEmpty ? null : saved;
      })().catchError((Object error) {
        _loadingAccount = null;
        throw error;
      });

  Future<bool> hasAccount() async {
    await loadAccount();
    return _accountToken != null;
  }

  Future<void> clearAccount() async {
    await _accountStorage.write('');
    _accountToken = null;
    await _storage.write('');
    _token = null;
  }

  Future<Json> signIn(String email, String password, bool register) async {
    await _initialize();
    final result = await _send(
      'POST',
      register ? '/auth/register' : '/auth/login',
      authenticated: false,
      guestToken: _token,
      body: {'email': email, 'password': password},
    ) as Json;
    final token = result['access_token'] as String;
    await _accountStorage.write(token);
    _accountToken = token;
    _loadingAccount = Future.value();
    return result['user'] as Json;
  }

  Future<dynamic> accountRequest(String method, String path) =>
      _send(method, path);

  Future<dynamic> adminRequest(String method, String path, {Json? body}) =>
      _send(method, '/admin$path', body: body);

  @override
  Future<CartSnapshot> cart() async =>
      CartSnapshot.fromJson(await _send('GET', '/cart') as Json);
  @override
  Future<CartSnapshot> setQuantity(
    int productId,
    int quantity,
    int version,
  ) async => CartSnapshot.fromJson(
    await _send(
      'PUT',
      '/cart/items/$productId',
      body: {'quantity': quantity, 'version': version},
    ) as Json,
  );
  @override
  Future<CheckoutQuote> quote() async =>
      CheckoutQuote.fromJson(await _send('GET', '/cart/quote') as Json);
  @override
  Future<StoreOrder> checkout(Json request, String idempotencyKey) async =>
      StoreOrder.fromJson(
        await _send('POST', '/orders', body: request, key: idempotencyKey)
            as Json,
      );
  @override
  Future<List<StoreOrder>> orders() async =>
      (await _send('GET', '/orders') as List)
          .map((x) => StoreOrder.fromJson(x as Json))
          .toList();
  @override
  Future<StoreOrder> order(String id) async => StoreOrder.fromJson(
    await _send('GET', '/orders/${Uri.encodeComponent(id)}') as Json,
  );
  @override
  Future<StoreOrder> pay(String id) async => StoreOrder.fromJson(
    await _send('POST', '/orders/${Uri.encodeComponent(id)}/pix') as Json,
  );
  @override
  Future<StoreOrder> refresh(String id) async => StoreOrder.fromJson(
    await _send('POST', '/orders/${Uri.encodeComponent(id)}/refresh') as Json,
  );
  @override
  Future<StoreOrder> cancel(String id) async => StoreOrder.fromJson(
    await _send('POST', '/orders/${Uri.encodeComponent(id)}/cancel') as Json,
  );
}
