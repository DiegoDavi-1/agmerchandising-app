import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const _brandsKey = 'cache_brands';
  static const _brandsMetaKey = 'cache_brands_meta';

  static String _brandFieldsKey(int brandId, {int? storeId}) => 'cache_brand_fields_${brandId}_${storeId ?? 0}';
  static String _brandFieldsMetaKey(int brandId, {int? storeId}) => 'cache_brand_fields_meta_${brandId}_${storeId ?? 0}';

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

  static Future<Map<String, dynamic>?> getCachedBrandFields(int brandId, {int? storeId}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_brandFieldsKey(brandId, storeId: storeId));
    final meta = prefs.getString(_brandFieldsMetaKey(brandId, storeId: storeId));

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
    int? storeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_brandFieldsKey(brandId, storeId: storeId), jsonEncode(data));
    await prefs.setString(
      _brandFieldsMetaKey(brandId, storeId: storeId),
      jsonEncode({
        'last_updated': lastUpdated,
        'cached_at': DateTime.now().toIso8601String(),
      }),
    );
  }
}
