import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';


// ──────────────────────────────────────────────
// CONFIGURATION
// Replace gasUrl with your deployed GAS Web App URL
// ──────────────────────────────────────────────
const String gasUrl =
    "https://script.google.com/macros/s/AKfycbwZXYN5MFij2iQBvtluVy1VKarPskWPrvcg0RP5SD0MKj6-MqMMtVUvn-zdbgYACaxz/exec";

void main() {
  runApp(const LaundryNavApp());
}

// ──────────────────────────────────────────────
// MODELS
// ──────────────────────────────────────────────

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

// ──────────────────────────────────────────────
// API SERVICE
// ──────────────────────────────────────────────

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

// FAVORITES SERVICE

class FavoritesService {
  static const String _favoritesKey = 'favorites_laundry';

  // Ambil daftar ID favorit dari SharedPreferences
  static Future<List<int>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? fav = prefs.getStringList(_favoritesKey);
    return fav?.map((id) => int.parse(id)).toList() ?? [];
  }

  // Cek apakah suatu laundry sudah difavoritkan
  static Future<bool> isFavorite(int placeId) async {
    final favorites = await getFavorites();
    return favorites.contains(placeId);
  }

  // Tambah ke favorit
  static Future<void> addFavorite(int placeId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> fav = (prefs.getStringList(_favoritesKey) ?? []).toList();
    if (!fav.contains(placeId.toString())) {
      fav.add(placeId.toString());
      await prefs.setStringList(_favoritesKey, fav);
    }
  }

  // Hapus dari favorit
  static Future<void> removeFavorite(int placeId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> fav = (prefs.getStringList(_favoritesKey) ?? []).toList();
    fav.removeWhere((id) => id == placeId.toString());
    await prefs.setStringList(_favoritesKey, fav);
  }
}


// ══════════════════════════════════════════════
// ✅ BARU: ROUTING SERVICE
//
// Menggantikan url_launcher + Google Maps.
// Berisi dua fungsi utama:
//   1. getCurrentLocation() — ambil posisi GPS user
//   2. getRouteFromOSRM()   — ambil jalur rute dari OSRM API
// ══════════════════════════════════════════════

class RoutingService {
  // ── 1. Ambil lokasi pengguna ────────────────────────────────────
  // Menangani: GPS mati, izin ditolak, izin permanen ditolak, timeout.
  static Future<Position> getCurrentLocation() async {
    // Cek apakah layanan lokasi (GPS) aktif
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'GPS tidak aktif. Aktifkan layanan lokasi di pengaturan perangkat.',
      );
    }

    // Cek & minta izin lokasi
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Izin lokasi ditolak. Berikan izin lokasi agar rute dapat ditampilkan.',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak permanen. Buka Pengaturan aplikasi untuk mengaktifkannya.',
      );
    }

    // Ambil posisi dengan timeout
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception(
          'Waktu mendapatkan lokasi habis. Pastikan GPS aktif dan coba lagi.',
        ),
      );
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Gagal mendapatkan lokasi: $e');
    }
  }

  // ── 2. Ambil rute dari OSRM ─────────────────────────────────────
  // Endpoint:
  //   https://router.project-osrm.org/route/v1/driving/
  //   {startLng},{startLat};{endLng},{endLat}
  //   ?overview=full&geometries=geojson
  //
  // Penting: OSRM menerima koordinat dalam urutan longitude,latitude (GeoJSON).
  // Response-nya di-parse menjadi List<LatLng> untuk PolylineLayer.
  //
  // Menangani: tidak ada internet, server error, rute tidak ditemukan.
  static Future<List<LatLng>> getRouteFromOSRM(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$startLng,$startLat;$endLng,$endLat'
      '?overview=full&geometries=geojson',
    );

    late http.Response response;
    try {
      response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception(
          'Koneksi ke server rute timeout. Periksa koneksi internet Anda.',
        ),
      );
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception(
        'Tidak ada koneksi internet. Periksa jaringan Anda dan coba lagi.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Server rute mengembalikan error (${response.statusCode}). Coba lagi nanti.',
      );
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Gagal memproses respons dari server rute.');
    }

    // OSRM mengembalikan field "code": "Ok" jika berhasil
    final code = data['code'] as String?;
    if (code != 'Ok') {
      throw Exception(
        'OSRM tidak dapat menemukan rute untuk tujuan ini (code: $code).',
      );
    }

    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw Exception('Tidak ada rute yang tersedia untuk tujuan ini.');
    }

    // Parse koordinat GeoJSON → List<LatLng>
    // GeoJSON format: [ [lng, lat], [lng, lat], ... ]  ← urutan terbalik!
    final coordinates = routes[0]['geometry']['coordinates'] as List;
    return coordinates
        .map((c) => LatLng(
              (c[1] as num).toDouble(), // latitude  = index 1
              (c[0] as num).toDouble(), // longitude = index 0
            ))
        .toList();
  }
}

// ──────────────────────────────────────────────
// APP ROOT
// ──────────────────────────────────────────────

class LaundryNavApp extends StatelessWidget {
  const LaundryNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laundry Finder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MainShell(),
    );
  }
}

// ──────────────────────────────────────────────
// MAIN SHELL — Bottom Navigation
// ──────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    MapScreen(),
    DirectoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Directory',
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// HOME SCREEN — Landing Page
// ──────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Place> _places = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() { _loading = true; _error = null; });
    try {
      final places = await ApiService.fetchPlaces();
      setState(() { _places = places; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: RefreshIndicator(
        onRefresh: _loadPlaces,
        child: CustomScrollView(
          slivers: [
            // ── Hero App Bar ──────────────────────────────
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: scheme.primary,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Laundry Finder',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary,
                        const Color(0xFF0D47A1),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Opacity(
                          opacity: 0.1,
                          child: Icon(
                            Icons.local_laundry_service,
                            size: 200,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 80, 16, 60),
                        child: Text(
                          'Temukan tempat laundry terdekat',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadPlaces,
                ),
              ],
            ),

            // ══════════════════════════════════════════════
            // Section Laundry Favorit 
            // ══════════════════════════════════════════════
            if (!_loading && _places.isNotEmpty)
              SliverToBoxAdapter(
                child: FutureBuilder<List<int>>(
                  future: FavoritesService.getFavorites(),
                  builder: (ctx, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    
                    final favoriteIds = snapshot.data ?? [];
                    final favorites = _places
                        .where((p) => favoriteIds.contains(p.id))
                        .toList();

                    if (favorites.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          'Belum ada laundry favorit',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _PlaceCard(place: favorites[i]),
                          childCount: favorites.length,
                        ),
                      ),
                    );
                  },
                ),
              ),

            // ── Section Title - "Laundry Favorit" ─────────
            if (!_loading && _places.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'Semua Tempat Laundry',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // ── Section Title ─────────────────────────────
            if (_loading || _places.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'Tempat Laundry',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // ── Section Title ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Tempat Laundry',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // ── Place Cards ───────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: _ErrorWidget(message: _error!, onRetry: _loadPlaces),
              )
            else if (_places.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('Belum ada data tempat.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _PlaceCard(place: _places[i]),
                    childCount: _places.length,
                  ),
                ),
              ),

            // ── Mini Map Preview ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'Peta Lokasi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 220,
                    child: _places.isEmpty
                        ? Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Text('Memuat peta...'),
                            ),
                          )
                        : _MiniMap(places: _places),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Place Card Widget ─────────────────────────────────────────

class _PlaceCard extends StatefulWidget {
  final Place place;
  const _PlaceCard({required this.place});

  @override
  State<_PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<_PlaceCard> {
  bool _isFavorite = false;
  double? _distance;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
    _calculateDistance();
  }

  Future<void> _checkFavorite() async {
    final isFav = await FavoritesService.isFavorite(widget.place.id);
    setState(() => _isFavorite = isFav);
  }

  Future<void> _calculateDistance() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) return;

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        final distance = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          widget.place.latitude,
          widget.place.longitude,
        );

        if (mounted) {
          setState(() => _distance = distance);
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await FavoritesService.removeFavorite(widget.place.id);
    } else {
      await FavoritesService.addFavorite(widget.place.id);
    }
    if (mounted) {
      setState(() => _isFavorite = !_isFavorite);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaceDetailScreen(place: widget.place),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Photo / Placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: widget.place.photoUrl.isNotEmpty
                    ? Image.network(
                        widget.place.photoUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _placeholderIcon(),
                      )
                    : _placeholderIcon(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.place.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.place.address,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // ✅ BARU: Tampilkan jarak atau "Menghitung jarak..."
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text(
                          _distance == null
                              ? 'Menghitung jarak...'
                              : _distance! < 1000
                                  ? '${_distance!.toStringAsFixed(0)} m'
                                  : '${(_distance! / 1000).toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          widget.place.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ✅ BARU: Favorite button
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.grey,
                  size: 20,
                ),
                onPressed: _toggleFavorite,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderIcon() => Container(
        width: 72,
        height: 72,
        color: const Color(0xFFE3F2FD),
        child: const Icon(
          Icons.local_laundry_service,
          color: Color(0xFF1565C0),
          size: 36,
        ),
      );
}

// ── Mini Map (OpenStreetMap) ───────────────────────────────────

class _MiniMap extends StatelessWidget {
  final List<Place> places;
  const _MiniMap({required this.places});

  @override
  Widget build(BuildContext context) {
    final validPlaces =
        places.where((p) => p.latitude != 0 && p.longitude != 0).toList();

    final center = validPlaces.isNotEmpty
        ? LatLng(validPlaces[0].latitude, validPlaces[0].longitude)
        : const LatLng(-7.2575, 112.7521); // Surabaya default

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 14),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.laundry_app',
        ),
        MarkerLayer(
          markers: validPlaces
              .map(
                (p) => Marker(
                  point: LatLng(p.latitude, p.longitude),
                  width: 36,
                  height: 36,
                  child: const Icon(
                    Icons.location_pin,
                    color: Color(0xFF1565C0),
                    size: 36,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// MAP SCREEN
// ──────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Place> _places = [];
  bool _loading = true;
  LatLng? _userLocation;
  Place? _selectedPlace;
  final MapController _mapController = MapController();

  // ════════════════════════════════════════════
  // ✅ BARU: State untuk rute OSRM di MapScreen
  // ════════════════════════════════════════════
  List<LatLng> _routePoints = [];  // titik-titik jalur rute dari OSRM
  bool _isLoadingRoute = false;    // true saat sedang fetch rute

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadPlaces();
    await _getUserLocation();
  }

  Future<void> _loadPlaces() async {
    try {
      final places = await ApiService.fetchPlaces();
      setState(() { _places = places; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {}
  }

  // ════════════════════════════════════════════
  // ✅ DIUBAH: _openRoute — tidak lagi membuka
  //    Google Maps / url_launcher.
  //
  //    Sekarang menggunakan RoutingService:
  //    1. getCurrentLocation() → posisi user
  //    2. getRouteFromOSRM()   → List<LatLng>
  //    3. _routePoints diupdate → PolylineLayer render garis
  // ════════════════════════════════════════════
  Future<void> _openRoute(Place place) async {
    setState(() {
      _isLoadingRoute = true;
      _routePoints = []; // hapus rute lama
    });

    try {
      // Langkah 1: ambil lokasi user
      final Position pos = await RoutingService.getCurrentLocation();

      // Update marker posisi user sekaligus
      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
        });
      }

      // Langkah 2: ambil rute dari OSRM
      final List<LatLng> points = await RoutingService.getRouteFromOSRM(
        pos.latitude,
        pos.longitude,
        place.latitude,
        place.longitude,
      );

      if (!mounted) return;

      // Langkah 3: simpan rute dan geser peta ke tujuan
      setState(() => _routePoints = points);
      _mapController.move(LatLng(place.latitude, place.longitude), 14);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final validPlaces =
        _places.where((p) => p.latitude != 0 && p.longitude != 0).toList();

    final center = _userLocation ??
        (validPlaces.isNotEmpty
            ? LatLng(validPlaces[0].latitude, validPlaces[0].longitude)
            : const LatLng(-7.2575, 112.7521));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Laundry'),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // ✅ BARU: indikator loading rute di AppBar
          if (_isLoadingRoute)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_userLocation != null) {
                _mapController.move(_userLocation!, 15);
              } else {
                _getUserLocation();
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // ════════════════════════════════════════════
                // ✅ DIUBAH: FlutterMap — ditambah PolylineLayer
                //    sebagai layer ke-2 setelah TileLayer.
                //    Hanya render jika _routePoints tidak kosong.
                // ════════════════════════════════════════════
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 14,
                    onTap: (_, _) => setState(() {
                      _selectedPlace = null;
                      // Uncomment baris berikut jika ingin rute hilang saat tap peta:
                      // _routePoints = [];
                    }),
                  ),
                  children: [
                    // Layer 1: Tile OSM (tidak berubah)
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.laundry_app',
                    ),

                    // ✅ BARU: Layer 2 — Polyline rute OSRM
                    // Hanya ditampilkan jika _routePoints tidak kosong.
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5.0,
                            color: Colors.blue.shade700,
                          ),
                        ],
                      ),

                    // Layer 3: Marker posisi user (tidak berubah)
                    if (_userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userLocation!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 3),
                              ),
                              child: const Icon(Icons.person,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),

                    // Layer 4: Marker laundry (tidak berubah)
                    MarkerLayer(
                      markers: validPlaces
                          .map(
                            (p) => Marker(
                              point: LatLng(p.latitude, p.longitude),
                              width: 44,
                              height: 44,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _selectedPlace = p;
                                  _routePoints = []; // hapus rute lama saat pilih laundry baru
                                }),
                                child: Icon(
                                  Icons.location_pin,
                                  color: _selectedPlace?.id == p.id
                                      ? Colors.orange
                                      : scheme.primary,
                                  size: 44,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),

                // ── Bottom Sheet untuk laundry yang dipilih ──────
                if (_selectedPlace != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedPlace!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star,
                                      size: 16, color: Colors.amber),
                                  Text(_selectedPlace!.rating
                                      .toStringAsFixed(1)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedPlace!.address,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.info_outline),
                                  label: const Text('Detail'),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlaceDetailScreen(
                                          place: _selectedPlace!),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // ════════════════════════════════════════
                              // ✅ DIUBAH: Tombol "Rute" di MapScreen
                              //    - Tidak lagi membuka Google Maps.
                              //    - Memanggil _openRoute() → OSRM → PolylineLayer.
                              //    - Saat loading: tampilkan spinner & nonaktifkan.
                              // ════════════════════════════════════════
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: scheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: _isLoadingRoute
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.directions),
                                  label: Text(
                                    _isLoadingRoute ? 'Memuat...' : 'Rute',
                                  ),
                                  onPressed: _isLoadingRoute
                                      ? null
                                      : () => _openRoute(_selectedPlace!),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ──────────────────────────────────────────────
// DIRECTORY SCREEN
// ──────────────────────────────────────────────

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<Place> _allPlaces = [];
  List<Category> _categories = [];
  List<Place> _filtered = [];
  String? _selectedCategoryId;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  String _sortFilter = 'all'; // 'all', 'nearest', 'highest_rating'
  LatLng? _userLocation;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Ambil lokasi user untuk filter "nearest"
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.deniedForever) {
            // Izin permanen ditolak, skip lokasi
          } else if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            _userLocation = LatLng(pos.latitude, pos.longitude);
          }
        }
      } catch (_) {
        // Jika gagal ambil lokasi, lanjut tanpa lokasi
      }

      final results = await Future.wait([
        ApiService.fetchPlaces(),
        ApiService.fetchCategories(),
      ]);
      _allPlaces = results[0] as List<Place>;
      _categories = results[1] as List<Category>;
      _applyFilter();
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    
    setState(() {
      // Filter berdasarkan kategori dan pencarian
      _filtered = _allPlaces.where((p) {
        final matchCat = _selectedCategoryId == null ||
            p.categoryId == _selectedCategoryId;
        final matchQ = q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q);
        return matchCat && matchQ;
      }).toList();

      // Terapkan sorting
      if (_sortFilter == 'nearest' && _userLocation != null) {
        // Hitung jarak dan sort dari terdekat ke terjauh
        _filtered.sort((a, b) {
          double distA = Geolocator.distanceBetween(
            _userLocation!.latitude,
            _userLocation!.longitude,
            a.latitude,
            a.longitude,
          );
          double distB = Geolocator.distanceBetween(
            _userLocation!.latitude,
            _userLocation!.longitude,
            b.latitude,
            b.longitude,
          );
          return distA.compareTo(distB);
        });
      } else if (_sortFilter == 'highest_rating') {
        // Sort rating dari tertinggi ke terendah
        _filtered.sort((a, b) => b.rating.compareTo(a.rating));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Direktori'),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorWidget(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Cari tempat laundry...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),

                    // Filter Sorting Chips (Jarak & Rating)
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _SortChip(
                            label: 'Semua',
                            icon: Icons.list,
                            selected: _sortFilter == 'all',
                            onTap: () {
                              setState(() => _sortFilter = 'all');
                              _applyFilter();
                            },
                          ),
                          _SortChip(
                            label: 'Terdekat',
                            icon: Icons.location_on_outlined,
                            selected: _sortFilter == 'nearest',
                            onTap: () {
                              setState(() => _sortFilter = 'nearest');
                              _applyFilter();
                            },
                          ),
                          _SortChip(
                            label: 'Rating Tertinggi',
                            icon: Icons.star_outlined,
                            selected: _sortFilter == 'highest_rating',
                            onTap: () {
                              setState(() => _sortFilter = 'highest_rating');
                              _applyFilter();
                            },
                          ),
                        ],
                      ),
                    ),

                    // Category filter chips
                    if (_categories.isNotEmpty)
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _CategoryChip(
                              label: 'Semua',
                              emoji: '🗂️',
                              selected: _selectedCategoryId == null,
                              onTap: () {
                                setState(() => _selectedCategoryId = null);
                                _applyFilter();
                              },
                            ),
                            ..._categories.map((c) => _CategoryChip(
                                  label: c.name,
                                  emoji: c.icon,
                                  selected: _selectedCategoryId == c.id,
                                  onTap: () {
                                    setState(() =>
                                        _selectedCategoryId = c.id);
                                    _applyFilter();
                                  },
                                )),
                          ],
                        ),
                      ),

                    // Place list
                    Expanded(
                      child: _filtered.isEmpty
                          ? const Center(
                              child: Text('Tidak ada hasil ditemukan.'))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 16),
                                itemCount: _filtered.length,
                                itemBuilder: (ctx, i) =>
                                    _PlaceCard(place: _filtered[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.primary,
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$emoji $label'),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.primary,
      ),
    );
  }
}

// ──────────────────────────────────────────────
// PLACE DETAIL SCREEN
// ══════════════════════════════════════════════
// ✅ DIUBAH: StatelessWidget → StatefulWidget
//    agar bisa menyimpan state routePoints dan isLoadingRoute.
// ──────────────────────────────────────────────

class PlaceDetailScreen extends StatefulWidget {
  final Place place;
  const PlaceDetailScreen({super.key, required this.place});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  // ════════════════════════════════════════════
  // ✅ BARU: State rute untuk PlaceDetailScreen
  // ════════════════════════════════════════════
  List<LatLng> routePoints = [];  // titik-titik jalur rute dari OSRM
  bool isLoadingRoute = false;    // true saat sedang fetch rute
  bool _isFavorite = false;
  double? _userDistance;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
    _calculateDistance();
  }

  Future<void> _checkFavorite() async {
    final isFav = await FavoritesService.isFavorite(widget.place.id);
    setState(() => _isFavorite = isFav);
  }

  Future<void> _calculateDistance() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) return;

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        final distance = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          widget.place.latitude,
          widget.place.longitude,
        );

        if (mounted) {
          setState(() => _userDistance = distance);
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await FavoritesService.removeFavorite(widget.place.id);
    } else {
      await FavoritesService.addFavorite(widget.place.id);
    }
    if (mounted) {
      setState(() => _isFavorite = !_isFavorite);
    }
  }

  // ════════════════════════════════════════════
  // ✅ DIUBAH: _openRoute — tidak lagi membuka
  //    Google Maps / url_launcher.
  //
  //    Alur baru:
  //    1. isLoadingRoute = true, routePoints dikosongkan
  //    2. getCurrentLocation() → posisi user
  //    3. getRouteFromOSRM()   → List<LatLng>
  //    4. setState routePoints → PolylineLayer render garis biru
  //    5. isLoadingRoute = false
  // ════════════════════════════════════════════
  Future<void> _openRoute() async {
    setState(() {
      isLoadingRoute = true;
      routePoints = []; // hapus rute lama
    });

    try {
      // Langkah 1: ambil lokasi user (dengan error handling GPS/izin)
      final Position pos = await RoutingService.getCurrentLocation();

      // Langkah 2: ambil rute dari OSRM
      final List<LatLng> points = await RoutingService.getRouteFromOSRM(
        pos.latitude,
        pos.longitude,
        widget.place.latitude,
        widget.place.longitude,
      );

      if (!mounted) return;

      // Langkah 3: simpan ke state → FlutterMap render PolylineLayer
      setState(() => routePoints = points);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoadingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: scheme.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.place.name,
                  style: const TextStyle(color: Colors.white)),
              background: widget.place.photoUrl.isNotEmpty
                  ? Image.network(
                      widget.place.photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _heroBg(scheme),
                    )
                  : _heroBg(scheme),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < widget.place.rating.floor()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(widget.place.rating.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Address
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: widget.place.address,
                  ),
                  const SizedBox(height: 10),

                  // ✅ BARU: Distance to Laundry
                  _InfoRow(
                    icon: Icons.directions_run,
                    text: _userDistance == null
                        ? 'Menghitung jarak...'
                        : _userDistance! < 1000
                            ? 'Jarak: ${_userDistance!.toStringAsFixed(0)} meter'
                            : 'Jarak: ${(_userDistance! / 1000).toStringAsFixed(1)} km',
                  ),
                  const SizedBox(height: 10),

                  // Coordinates
                  _InfoRow(
                    icon: Icons.gps_fixed,
                    text:
                        '${widget.place.latitude.toStringAsFixed(6)}, ${widget.place.longitude.toStringAsFixed(6)}',
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (widget.place.description.isNotEmpty) ...[
                    const Text(
                      'Deskripsi',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(widget.place.description,
                        style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 20),
                  ],

                  // ════════════════════════════════════════════
                  // ✅ DIUBAH: FlutterMap mini — ditambah PolylineLayer
                  //
                  //    Layer susunan:
                  //    1. TileLayer    — tile OSM (tidak berubah)
                  //    2. PolylineLayer — garis rute biru (BARU, kondisional)
                  //    3. MarkerLayer  — marker tujuan (tidak berubah)
                  //
                  //    PolylineLayer hanya muncul setelah "Buka Rute" ditekan
                  //    dan berhasil mendapat data dari OSRM.
                  // ════════════════════════════════════════════
                  if (widget.place.latitude != 0 && widget.place.longitude != 0) ...[
                    const Text(
                      'Lokasi',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 220, // sedikit lebih tinggi agar rute terlihat jelas
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              widget.place.latitude,
                              widget.place.longitude,
                            ),
                            initialZoom: 15,
                          ),
                          children: [
                            // Layer 1: Tile OSM
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.example.laundry_app',
                            ),

                            // ✅ BARU: Layer 2 — Polyline rute OSRM
                            // Hanya ditampilkan jika routePoints tidak kosong.
                            // Garis berwarna biru, lebar 5.
                            if (routePoints.isNotEmpty)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: routePoints,
                                    strokeWidth: 5.0,
                                    color: Colors.blue.shade700,
                                  ),
                                ],
                              ),

                            // Layer 3: Marker tujuan (tidak berubah)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    widget.place.latitude,
                                    widget.place.longitude,
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: Icon(Icons.location_pin,
                                      color: scheme.primary, size: 40),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ════════════════════════════════════════════
                  // Tombol buka route dan Fav
                  // ════════════════════════════════════════════
                  Row(
                    children: [
                      // Favorite button
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: _isFavorite ? Colors.red : null,
                          ),
                          label: Text(_isFavorite ? 'Favorit' : 'Tambah Favorit'),
                          onPressed: _toggleFavorite,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Route button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: isLoadingRoute
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Icon(Icons.directions),
                          label: Text(
                            isLoadingRoute ? 'Memuat Rute...' : 'Buka Rute',
                            style: const TextStyle(fontSize: 16),
                          ),
                          onPressed: isLoadingRoute ? null : _openRoute,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBg(ColorScheme scheme) => Container(
        color: scheme.primaryContainer,
        child: Center(
          child: Icon(Icons.local_laundry_service,
              size: 80, color: scheme.primary),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: Colors.grey.shade800)),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// ERROR WIDGET
// ──────────────────────────────────────────────

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorWidget({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat data',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}