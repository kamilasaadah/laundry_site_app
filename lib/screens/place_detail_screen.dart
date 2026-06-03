import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place.dart';
import '../services/routing_service.dart';
import '../services/favorites_service.dart';
import '../utils/constants.dart';
import '../widgets/shared_widgets.dart';

class PlaceDetailScreen extends StatefulWidget {
  final Place place;
  const PlaceDetailScreen({super.key, required this.place});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  List<LatLng> routePoints = [];
  bool isLoadingRoute = false;
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
    if (mounted) setState(() => _isFavorite = isFav);
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
        if (mounted) setState(() => _userDistance = distance);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await FavoritesService.removeFavorite(widget.place.id);
    } else {
      await FavoritesService.addFavorite(widget.place.id);
    }
    if (mounted) setState(() => _isFavorite = !_isFavorite);
  }

  Future<void> _openRoute() async {
    setState(() {
      isLoadingRoute = true;
      routePoints = [];
    });
    try {
      final Position pos = await RoutingService.getCurrentLocation();
      final List<LatLng> points = await RoutingService.getRouteFromOSRM(
        pos.latitude,
        pos.longitude,
        widget.place.latitude,
        widget.place.longitude,
      );
      if (!mounted) return;
      setState(() => routePoints = points);
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
      if (mounted) setState(() => isLoadingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              title: Text(
                widget.place.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: widget.place.photoUrl.isNotEmpty
                  ? Image.network(
                      widget.place.photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _heroBg(),
                    )
                  : _heroBg(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isFavorite ? AppColors.accent : Colors.white,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < widget.place.rating.floor()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppColors.starColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.place.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InfoTile(
                    icon: Icons.location_on_outlined,
                    text: widget.place.address,
                  ),
                  const SizedBox(height: 10),
                  InfoTile(
                    icon: Icons.directions_run_rounded,
                    text: _userDistance == null
                        ? 'Menghitung jarak...'
                        : _userDistance! < 1000
                            ? 'Jarak: ${_userDistance!.toStringAsFixed(0)} meter'
                            : 'Jarak: ${(_userDistance! / 1000).toStringAsFixed(1)} km',
                  ),
                  const SizedBox(height: 10),
                  InfoTile(
                    icon: Icons.gps_fixed_rounded,
                    text:
                        '${widget.place.latitude.toStringAsFixed(6)}, ${widget.place.longitude.toStringAsFixed(6)}',
                  ),
                  if (widget.place.description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Deskripsi',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.place.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.6,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (widget.place.latitude != 0 &&
                      widget.place.longitude != 0) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Lokasi',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 220,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              widget.place.latitude,
                              widget.place.longitude,
                            ),
                            initialZoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.example.laundry_app',
                            ),
                            if (routePoints.isNotEmpty)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: routePoints,
                                    strokeWidth: 5.0,
                                    color: AppColors.routeLine,
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    widget.place.latitude,
                                    widget.place.longitude,
                                  ),
                                  width: 44,
                                  height: 52,
                                  child: const MapPin(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isFavorite
                                ? AppColors.accent
                                : AppColors.primary,
                            side: BorderSide(
                              color: _isFavorite
                                  ? AppColors.accent
                                  : AppColors.primary,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: Icon(
                            _isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _isFavorite ? 'Favorit' : 'Tambah Favorit',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          onPressed: _toggleFavorite,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: isLoadingRoute
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Icon(Icons.route_rounded, size: 18),
                          label: Text(
                            isLoadingRoute ? 'Memuat Rute...' : 'Buka Rute',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
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

  Widget _heroBg() => Container(
        color: AppColors.primaryLight,
        child: const Center(
          child: Icon(Icons.local_laundry_service_rounded,
              size: 80, color: AppColors.primary),
        ),
      );
}
