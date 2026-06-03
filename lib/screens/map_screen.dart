import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place.dart';
import '../services/api_service.dart';
import '../services/routing_service.dart';
import '../services/favorites_service.dart';
import '../utils/constants.dart';
import '../widgets/shared_widgets.dart';
import 'place_detail_screen.dart';

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
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;
  bool _isFavoriteSelected = false;
  double? _selectedDistance;

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
      setState(() {
        _places = places;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
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
      setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }

  Future<void> _checkSelectedFavorite(Place place) async {
    final isFav = await FavoritesService.isFavorite(place.id);
    if (mounted) setState(() => _isFavoriteSelected = isFav);
  }

  Future<void> _calculateSelectedDistance(Place place) async {
    try {
      if (_userLocation == null) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return;
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) return;
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _userLocation = LatLng(pos.latitude, pos.longitude);
      }

      final distance = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        place.latitude,
        place.longitude,
      );
      if (mounted) setState(() => _selectedDistance = distance);
    } catch (_) {}
  }

  Future<void> _toggleSelectedFavorite() async {
    if (_selectedPlace == null) return;
    if (_isFavoriteSelected) {
      await FavoritesService.removeFavorite(_selectedPlace!.id);
    } else {
      await FavoritesService.addFavorite(_selectedPlace!.id);
    }
    if (mounted) setState(() => _isFavoriteSelected = !_isFavoriteSelected);
  }

  Future<void> _openRoute(Place place) async {
    setState(() {
      _isLoadingRoute = true;
      _routePoints = [];
    });
    try {
      final Position pos = await RoutingService.getCurrentLocation();
      if (mounted) {
        setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
      }
      final List<LatLng> points = await RoutingService.getRouteFromOSRM(
        pos.latitude,
        pos.longitude,
        place.latitude,
        place.longitude,
      );
      if (!mounted) return;
      setState(() => _routePoints = points);
      _mapController.move(LatLng(place.latitude, place.longitude), 14);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validPlaces =
        _places.where((p) => p.latitude != 0 && p.longitude != 0).toList();
    final center = _userLocation ??
        (validPlaces.isNotEmpty
            ? LatLng(validPlaces[0].latitude, validPlaces[0].longitude)
            : const LatLng(-7.2575, 112.7521));

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Stack(
        children: [
          if (_loading)
            const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                onTap: (_, __) => setState(() {
                  _selectedPlace = null;
                }),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.laundry_app',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 5.0,
                        color: AppColors.routeLine,
                      ),
                    ],
                  ),
                if (_userLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _userLocation!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.userDot,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: validPlaces
                      .map((p) => Marker(
                            point: LatLng(p.latitude, p.longitude),
                            width: 48,
                            height: 56,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPlace = p;
                                  _routePoints = [];
                                  _selectedDistance = null;
                                });
                                _checkSelectedFavorite(p);
                                _calculateSelectedDistance(p);
                              },
                              child: MapPin(
                                isActive: _selectedPlace?.id == p.id,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),

          // ── Search bar overlay ──────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 14),
                        Icon(Icons.search_rounded,
                            color: AppColors.textMuted, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Cari tempat laundry...',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_userLocation != null) {
                      _mapController.move(_userLocation!, 15);
                    } else {
                      _getUserLocation();
                    }
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isLoadingRoute
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded,
                            color: AppColors.primary, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom card for selected place (LARGER) ──
          if (_selectedPlace != null)
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Photo thumbnail — LARGER (70x70)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _selectedPlace!.photoUrl.isNotEmpty
                              ? Image.network(
                                  _selectedPlace!.photoUrl,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _mapCardPlaceholder(),
                                )
                              : _mapCardPlaceholder(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPlace!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _selectedPlace!.address,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      size: 14, color: AppColors.starColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    _selectedPlace!.rating
                                        .toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Favorite button
                        GestureDetector(
                          onTap: _toggleSelectedFavorite,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _isFavoriteSelected
                                  ? const Color(0xFFFFECF0)
                                  : AppColors.bgSearch,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isFavoriteSelected
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: _isFavoriteSelected
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // ── Distance card ──────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDistance == null
                                  ? 'Menghitung jarak...'
                                  : _selectedDistance! < 1000
                                      ? 'Jarak: ${_selectedDistance!.toStringAsFixed(0)} m'
                                      : 'Jarak: ${(_selectedDistance! / 1000).toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryMid,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                  color: AppColors.primary, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 11),
                            ),
                            icon: const Icon(Icons.info_outline_rounded,
                                size: 16),
                            label: const Text('Detail',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
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
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 11),
                            ),
                            icon: _isLoadingRoute
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Icon(Icons.route_rounded, size: 16),
                            label: Text(
                              _isLoadingRoute
                                  ? 'Memuat...'
                                  : 'Buka Rute',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
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

  Widget _mapCardPlaceholder() => Container(
        width: 70,
        height: 70,
        color: AppColors.primaryLight,
        child: const Center(
          child: Icon(Icons.local_laundry_service_rounded,
              color: AppColors.primary, size: 32),
        ),
      );
}
