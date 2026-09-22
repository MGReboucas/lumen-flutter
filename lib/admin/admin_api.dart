import '../checkout/commerce_api.dart';
import '../store/catalog_api.dart';

class AdminProduct {
  AdminProduct.fromJson(Json data)
    : id = data['id'] as int,
      name = data['name'] as String,
      description = data['description'] as String?,
      priceCents = data['price_cents'] as int,
      stock = data['stock'] as int,
      categoryId = data['category_id'] as int?,
      categoryName = data['category_name'] as String?,
      imageUrl = data['image_url'] as String?,
      active = data['is_active'] as bool,
      version = data['version'] as int,
      package = {
        for (final entry in packageDefaults.entries)
          entry.key: data[entry.key] as int? ?? entry.value,
      };
  // Older responses remain readable during the backend rollout.
  static const packageDefaults = {
    'weight_grams': 500,
    'height_cm': 10,
    'width_cm': 15,
    'length_cm': 20,
  };
  final Map<String, int> package;
  final int id, priceCents, stock, version;
  final int? categoryId;
  final String name;
  final String? description, categoryName, imageUrl;
  final bool active;
}

abstract class AdminRepository {
  Future<List<AdminProduct>> products({
    String search = '',
    bool? active,
    int skip = 0,
  });
  Future<AdminProduct> product(int id);
  Future<AdminProduct> save(Json data, {int? id});
  Future<List<StoreCategory>> categories();
  Future<StoreCategory> createCategory(String name);
}

class AdminApi implements AdminRepository {
  AdminApi(this.api);
  final CommerceApi api;

  @override
  Future<List<AdminProduct>> products({
    String search = '',
    bool? active,
    int skip = 0,
  }) async {
    final query = Uri(
      queryParameters: {
        'search': search,
        'skip': '$skip',
        'limit': '20',
        if (active != null) 'is_active': '$active',
      },
    ).query;
    return (await api.adminRequest('GET', '/products?$query') as List)
        .map((p) => AdminProduct.fromJson(p as Json))
        .toList();
  }

  @override
  Future<AdminProduct> product(int id) async => AdminProduct.fromJson(
    await api.adminRequest('GET', '/products/$id') as Json,
  );
  @override
  Future<AdminProduct> save(Json data, {int? id}) async =>
      AdminProduct.fromJson(
        await api.adminRequest(
          id == null ? 'POST' : 'PUT',
          id == null ? '/products' : '/products/$id',
          body: data,
        ) as Json,
      );
  @override
  Future<List<StoreCategory>> categories() async =>
      (await api.adminRequest('GET', '/categories') as List)
          .map((c) => StoreCategory(c['id'] as int, c['name'] as String))
          .toList();
  @override
  Future<StoreCategory> createCategory(String name) async {
    final data = await api.adminRequest(
      'POST',
      '/categories',
      body: {'name': name},
    ) as Json;
    return StoreCategory(data['id'] as int, data['name'] as String);
  }
}
