import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../checkout/commerce_api.dart';
import '../store/catalog_api.dart';

class AccountController extends ChangeNotifier {
  AccountController(this.api, {SessionStorage? favoritesStorage})
    : storage =
          favoritesStorage ??
          SecureSessionStorage(CommerceApi.defaultBaseUrl, scope: 'favorites');
  final CommerceApi api;
  final SessionStorage storage;
  Json? user;
  List<StoreProduct> favorites = [];
  bool loading = true;
  String? error;
  final Set<int> updating = {};
  bool _disposed = false;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  bool isFavorite(int id) => favorites.any((x) => x.id == id);
  bool get isAdmin => user?['is_admin'] == true;

  Future<void> initialize() async {
    loading = true;
    error = null;
    _changed();
    try {
      if (await api.hasAccount()) {
        try {
          user = await api.accountRequest('GET', '/auth/me') as Json;
        } on CommerceException catch (e) {
          if (e.status != 401) rethrow;
          await api.clearAccount();
          user = null;
        }
      }
      await _loadFavorites();
    } catch (_) {
      error = 'Não foi possível carregar sua conta. Tente novamente.';
    } finally {
      loading = false;
      _changed();
    }
  }

  Future<void> _loadFavorites() async {
    final dynamic data = user != null
        ? await api.accountRequest('GET', '/favorites')
        : jsonDecode((await storage.read()) ?? '[]');
    favorites = (data as List)
        .map((x) => StoreProduct.fromJson(x as Json))
        .toList();
  }

  Future<void> signIn(String email, String password, bool register) async {
    user = await api.signIn(email.trim(), password, register);
    error = null;
    favorites = [];
    try {
      await _loadFavorites();
    } catch (_) {
      error = 'Conta conectada. Atualize para carregar seus favoritos.';
    }
    _changed();
  }

  Future<void> logout() async {
    try {
      await api.accountRequest('POST', '/auth/logout');
    } on CommerceException catch (e) {
      if (e.status != 401) rethrow;
    }
    await api.clearAccount();
    user = null;
    favorites = [];
    error = null;
    try {
      await _loadFavorites();
    } catch (_) {
      error = 'Não foi possível carregar os favoritos deste aparelho.';
    }
    _changed();
  }

  Future<void> toggle(StoreProduct product) async {
    if (loading || updating.isNotEmpty) return;
    updating.add(product.id);
    _changed();
    try {
      final selected = isFavorite(product.id);
      final next = favorites.where((x) => x.id != product.id).toList();
      if (!selected) next.add(product);
      if (user != null) {
        await api.accountRequest(
          selected ? 'DELETE' : 'PUT',
          '/favorites/${product.id}',
        );
      } else {
        await storage.write(
          jsonEncode(
            next
                .map(
                  (p) => {
                    'id': p.id,
                    'name': p.name,
                    'description': p.description,
                    'price': p.price,
                    'stock': p.stock,
                    'category_name': p.categoryName,
                    'image_url': p.imageUrl,
                  },
                )
                .toList(),
          ),
        );
      }
      favorites = next;
    } finally {
      updating.remove(product.id);
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
