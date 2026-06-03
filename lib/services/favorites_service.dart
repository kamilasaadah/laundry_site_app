import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _favoritesKey = 'favorites_list';

  static Future<List<int>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? fav = prefs.getStringList(_favoritesKey);
    return fav?.map((id) => int.parse(id)).toList() ?? [];
  }

  static Future<bool> isFavorite(int placeId) async {
    final favorites = await getFavorites();
    return favorites.contains(placeId);
  }

  static Future<void> addFavorite(int placeId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> fav =
        (prefs.getStringList(_favoritesKey) ?? []).toList();
    if (!fav.contains(placeId.toString())) {
      fav.add(placeId.toString());
      await prefs.setStringList(_favoritesKey, fav);
    }
  }

  static Future<void> removeFavorite(int placeId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> fav =
        (prefs.getStringList(_favoritesKey) ?? []).toList();
    fav.removeWhere((id) => id == placeId.toString());
    await prefs.setStringList(_favoritesKey, fav);
  }
}
