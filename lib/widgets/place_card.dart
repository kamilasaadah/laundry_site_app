import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place.dart';
import '../services/favorites_service.dart';
import '../screens/place_detail_screen.dart';
import '../utils/constants.dart';

// ──────────────────────────────────────────────
// PLACE CARD VERTICAL (for Home — photo on top, larger)
// ──────────────────────────────────────────────

class PlaceCardVertical extends StatefulWidget {
  final Place place;
  final VoidCallback? onFavoriteChanged;
  const PlaceCardVertical({required this.place, this.onFavoriteChanged});

  @override
  State<PlaceCardVertical> createState() => PlaceCardVerticalState();
}

class PlaceCardVerticalState extends State<PlaceCardVertical> {
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
        if (mounted) setState(() => _distance = distance);
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
      widget.onFavoriteChanged?.call();
    }
  }

  String get _distanceText {
    if (_distance == null) return 'Menghitung...';
    if (_distance! < 1000) return '${_distance!.toStringAsFixed(0)} m';
    return '${(_distance! / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaceDetailScreen(place: widget.place),
          ),
        ).then((_) => _checkFavorite()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo on top — LARGER (240 height) ─────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              child: Stack(
                children: [
                  widget.place.photoUrl.isNotEmpty
                      ? Image.network(
                          widget.place.photoUrl,
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _photoPlaceholder(),
                        )
                      : _photoPlaceholder(),
                  // Favorite button overlay
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _toggleFavorite,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _isFavorite
                              ? AppColors.accent
                              : AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Info below ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.place.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.place.address,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              _distanceText,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryMid,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: AppColors.starColor),
                            const SizedBox(width: 4),
                            Text(
                              widget.place.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB07A00),
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() => Container(
        width: double.infinity,
        height: 240,
        color: AppColors.primaryLight,
        child: const Center(
          child: Icon(
            Icons.local_laundry_service_rounded,
            color: AppColors.primary,
            size: 56,
          ),
        ),
      );
}

// ──────────────────────────────────────────────
// PLACE CARD LARGE (horizontal — for Favorites & Directory, larger)
// ──────────────────────────────────────────────

class PlaceCardLarge extends StatefulWidget {
  final Place place;
  final VoidCallback? onFavoriteChanged;
  const PlaceCardLarge({required this.place, this.onFavoriteChanged});

  @override
  State<PlaceCardLarge> createState() => PlaceCardLargeState();
}

class PlaceCardLargeState extends State<PlaceCardLarge> {
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
        if (mounted) setState(() => _distance = distance);
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
      widget.onFavoriteChanged?.call();
    }
  }

  String get _distanceText {
    if (_distance == null) return 'Menghitung...';
    if (_distance! < 1000) return '${_distance!.toStringAsFixed(0)} m';
    return '${(_distance! / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaceDetailScreen(place: widget.place),
          ),
        ).then((_) => _checkFavorite()),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ── Photo — LARGER (100x100) ──────────
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.place.photoUrl.isNotEmpty
                    ? Image.network(
                        widget.place.photoUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.place.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.place.address,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          _distanceText,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.star_rounded,
                            size: 14, color: AppColors.starColor),
                        const SizedBox(width: 3),
                        Text(
                          widget.place.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Favorite button
                  GestureDetector(
                    onTap: _toggleFavorite,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        _isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _isFavorite
                            ? AppColors.accent
                            : AppColors.textMuted,
                        size: 22,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.local_laundry_service_rounded,
          color: AppColors.primary,
          size: 40,
        ),
      );
}
