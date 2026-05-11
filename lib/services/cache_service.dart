import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const _brandsKey = 'cache_brands';
  static const _brandsMetaKey = 'cache_brands_meta';

  static String _brandFieldsKey(int brandId) => 'cache_brand_fields_$brandId';
  static String _brandFieldsMetaKey(int brandId) => 'cache_brand_fields_meta_$brandId';

  static Future<Map<String, dynamic>?> getCachedBrands() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_brandsKey);
    final meta = prefs.getString(_brandsMetaKey);

    if (data == null || meta == null) return null;

    return {
      'data': jsonDecode(data) as List<dynamic>,
      'meta': jsonDecode(meta) as Map<String, dynamic>,
    };
  }

  static Future<void> setCachedBrands({
    required List<dynamic> data,
    required String? lastUpdated,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_brandsKey, jsonEncode(data));
    await prefs.setString(
      _brandsMetaKey,
      jsonEncode({
        'last_updated': lastUpdated,
        'cached_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<Map<String, dynamic>?> getCachedBrandFields(int brandId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_brandFieldsKey(brandId));
    final meta = prefs.getString(_brandFieldsMetaKey(brandId));

    if (data == null || meta == null) return null;

    return {
      'data': jsonDecode(data) as List<dynamic>,
      'meta': jsonDecode(meta) as Map<String, dynamic>,
    };
  }

  static Future<void> setCachedBrandFields({
    required int brandId,
    required List<dynamic> data,
    required String? lastUpdated,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_brandFieldsKey(brandId), jsonEncode(data));
    await prefs.setString(
      _brandFieldsMetaKey(brandId),
      jsonEncode({
        'last_updated': lastUpdated,
        'cached_at': DateTime.now().toIso8601String(),
      }),
    );
  }
}
