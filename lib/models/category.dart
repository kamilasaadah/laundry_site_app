class Category {
  final String id;
  final String name;
  final String icon;

  const Category({required this.id, required this.name, required this.icon});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id']?.toString() ?? '',
        name: j['name'] ?? '',
        icon: j['icon'] ?? '📍',
      );
}
