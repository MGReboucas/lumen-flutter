import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    this.categoryName,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final String? categoryName;
  final String? imageUrl;

  factory StoreProduct.fromJson(Map<String, dynamic> json) => StoreProduct(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    price: (json['price'] as num).toDouble(),
    stock: json['stock'] as int,
    categoryName: json['category_name'] as String?,
    imageUrl: json['image_url'] as String?,
  );

  String get shortDescription => categoryName ?? description ?? 'Seleção Lumen';

  String get formattedPrice =>
      'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
}

const lumenDemoProduct = StoreProduct(
  id: 0,
  name: 'Vestido Aura',
  description: 'Cetim champagne · edição limitada',
  price: 9.90,
  stock: 12,
  categoryName: 'Coleção Vista sua essência',
  imageUrl: 'https://lumen-flutter-blond.vercel.app/products/vestido-aura.png',
);

class StoreCategory {
  const StoreCategory(this.id, this.name);
  final int id;
  final String name;
}

abstract class ProductsRepository {
  Future<List<StoreProduct>> listProducts({
    String? search,
    int? categoryId,
    int skip = 0,
    int limit = 20,
  });
  Future<StoreProduct> product(int id);
  Future<List<StoreCategory>> categories();
}

class ProductApi implements ProductsRepository {
  ProductApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? apiBaseUrl;
  final http.Client _client;
  final String _baseUrl;
  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    try {
      final uri = Uri.parse('${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path')
          .replace(queryParameters: query);
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw ProductApiException('Não foi possível carregar o catálogo.');
      }
      return jsonDecode(response.body);
    } catch (_) {
      throw ProductApiException(
        'Não foi possível conectar à loja. Confira a conexão e tente novamente.',
      );
    }
  }

  @override
  Future<List<StoreProduct>> listProducts({
    String? search,
    int? categoryId,
    int skip = 0,
    int limit = 20,
  }) async =>
      (await _get('/products', {
            'skip': '$skip',
            'limit': '$limit',
            if (search != null && search.isNotEmpty) 'search': search,
            if (categoryId != null) 'category_id': '$categoryId',
          }) as List)
          .map((x) => StoreProduct.fromJson(x as Map<String, dynamic>))
          .toList();
  @override
  Future<StoreProduct> product(int id) async => StoreProduct.fromJson(
    await _get('/products/$id') as Map<String, dynamic>,
  );
  @override
  Future<List<StoreCategory>> categories() async =>
      (await _get('/categories') as List)
          .map((x) => StoreCategory(x['id'] as int, x['name'] as String))
          .toList();
}

class ProductApiException implements Exception {
  ProductApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
