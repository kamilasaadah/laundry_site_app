import 'package:flutter/material.dart' hide FilterChip;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/place.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/place_card.dart';
import '../widgets/shared_widgets.dart';

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
  String _sortFilter = 'all';
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission != LocationPermission.deniedForever &&
              (permission == LocationPermission.always ||
                  permission == LocationPermission.whileInUse)) {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            _userLocation = LatLng(pos.latitude, pos.longitude);
          }
        }
      } catch (_) {}

      final results = await Future.wait([
        ApiService.fetchPlaces(),
        ApiService.fetchCategories(),
      ]);
      _allPlaces = results[0] as List<Place>;
      _categories = results[1] as List<Category>;
      _applyFilter();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _allPlaces.where((p) {
        final matchCat = _selectedCategoryId == null ||
            p.categoryId == _selectedCategoryId;
        final matchQ = q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q);
        return matchCat && matchQ;
      }).toList();

      if (_sortFilter == 'nearest' && _userLocation != null) {
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
        _filtered.sort((a, b) => b.rating.compareTo(a.rating));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('Direktori')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? AppErrorWidget(message: _error!, onRetry: _load)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Cari tempat laundry...',
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                        ),
                      ),
                    ),

                    // Sort chips
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          FilterChip(
                            label: 'Semua',
                            icon: Icons.list_rounded,
                            selected: _sortFilter == 'all',
                            onTap: () {
                              setState(() => _sortFilter = 'all');
                              _applyFilter();
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: 'Terdekat',
                            icon: Icons.location_on_rounded,
                            selected: _sortFilter == 'nearest',
                            onTap: () {
                              setState(() => _sortFilter = 'nearest');
                              _applyFilter();
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: 'Rating Tertinggi',
                            icon: Icons.star_rounded,
                            selected: _sortFilter == 'highest_rating',
                            onTap: () {
                              setState(() => _sortFilter = 'highest_rating');
                              _applyFilter();
                            },
                          ),
                        ],
                      ),
                    ),

                    // Category chips
                    if (_categories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            FilterChip(
                              label: 'Semua',
                              emoji: '🗂️',
                              selected: _selectedCategoryId == null,
                              onTap: () {
                                setState(() => _selectedCategoryId = null);
                                _applyFilter();
                              },
                            ),
                            ..._categories.map((c) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: FilterChip(
                                  label: c.name,
                                  emoji: c.icon,
                                  selected: _selectedCategoryId == c.id,
                                  onTap: () {
                                    setState(
                                        () => _selectedCategoryId = c.id);
                                    _applyFilter();
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),
                    const Divider(height: 1),

                    // Place list — LARGER cards
                    Expanded(
                      child: _filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'Tidak ada hasil ditemukan.',
                                style: TextStyle(
                                    color: AppColors.textSecondary),
                              ),
                            )
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 12, 16, 24),
                                itemCount: _filtered.length,
                                itemBuilder: (ctx, i) =>
                                    PlaceCardLarge(place: _filtered[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
