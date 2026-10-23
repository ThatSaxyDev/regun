import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/models/economy/shop_catalog.dart';
import 'package:regun/services/account/account_api.dart';

/// Only shop entry awaits this. Cached ownership never depends on availability.
class ShopRepository extends ChangeNotifier {
  ShopRepository({AccountApi? api}) : api = api ?? AccountApi();
  static final shared = ShopRepository();
  final AccountApi api;
  ShopCatalog catalog = ShopCatalog.bundled;
  String? issue;
  bool loading = false, live = false;
  Future<void>? _refresh;
  String get _cacheKey =>
      'shop.catalog.v1.${api.endpoint?.origin ?? 'unconfigured'}';
  Future<void> refresh() =>
      _refresh ??= _load().whenComplete(() => _refresh = null);
  Future<void> _load() async {
    loading = true;
    issue = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (!live && cached != null) {
        try {
          catalog = ShopCatalog.fromJson(
            jsonDecode(cached) as Map<String, dynamic>,
          );
        } catch (_) {
          /* Retain bundled fallback. */
        }
        notifyListeners();
      }
      final data = await api.request('/economy/v1/catalog');
      final next = ShopCatalog.fromJson(data);
      catalog = next;
      live = true;
      await prefs.setString(_cacheKey, jsonEncode(next.toJson()));
    } catch (_) {
      live = false;
      issue = 'Connect to check current prices. Owned styles still work.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
