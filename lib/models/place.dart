class Place {
  final int id;
  final String name;
  final String categoryId;
  final String address;
  final double latitude;
  final double longitude;
  final String description;
  final double rating;
  final String photoUrl;

  const Place({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.rating,
    required this.photoUrl,
  });

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        id: _toInt(j['id']),
        name: j['name'] ?? '',
        categoryId: j['category_id']?.toString() ?? '',
        address: j['address'] ?? '',
        latitude: _toDouble(j['latitude']),
        longitude: _toDouble(j['longitude']),
        description: j['description'] ?? '',
        rating: _toDouble(j['rating']),
        photoUrl: j['photo_url'] ?? '',
      );

  static int _toInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
  static double _toDouble(dynamic v) =>
      v is double ? v : double.tryParse(v?.toString() ?? '') ?? 0.0;
}
