import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/place.dart';
import '../models/category.dart';
import '../utils/constants.dart';

class ApiService {
  static Future<List<Place>> fetchPlaces({String? categoryId}) async {
    final uri = Uri.parse(gasUrl).replace(queryParameters: {
      'path': '/api/places',
      ...?(categoryId != null ? {'category_id': categoryId} : null),
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}');
    final List data = jsonDecode(res.body);
    return data.map((e) => Place.fromJson(e)).toList();
  }

  static Future<Place> fetchPlaceById(int id) async {
    final uri = Uri.parse(gasUrl)
        .replace(queryParameters: {'path': '/api/places/$id'});
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Not found');
    return Place.fromJson(jsonDecode(res.body));
  }

  static Future<List<Category>> fetchCategories() async {
    final uri = Uri.parse(gasUrl)
        .replace(queryParameters: {'path': '/api/categories'});
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Server error');
    final List data = jsonDecode(res.body);
    return data.map((e) => Category.fromJson(e)).toList();
  }
}
