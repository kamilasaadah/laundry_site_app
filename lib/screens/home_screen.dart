import 'package:flutter/material.dart';
import '../models/place.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/place_card.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/mini_map.dart';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final places = await ApiService.fetchPlaces();
      setState(() {
        _places = places;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show max 3 places on home
    final displayedPlaces = _places.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadPlaces,
        child: CustomScrollView(
          slivers: [
            // ── AppBar ──────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.bgCard,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: 64,
              title: const Text(
                'Home',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: _loadPlaces,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'AK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    readOnly: true,
                    decoration: const InputDecoration(
                      hintText: 'Cari tempat laundry...',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                ),
              ),
            ),

            // ── All places section (max 3) ──────────
            if (!_loading && displayedPlaces.isNotEmpty)
              const SliverToBoxAdapter(
                child: SectionLabel(label: 'Laundry Terdekat'),
              ),

            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: AppErrorWidget(
                    message: _error!, onRetry: _loadPlaces),
              )
            else if (_places.isEmpty)
              const SliverFillRemaining(
                child: Center(
                    child: Text('Belum ada data tempat.',
                        style:
                            TextStyle(color: AppColors.textSecondary))),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => PlaceCardVertical(place: displayedPlaces[i]),
                    childCount: displayedPlaces.length,
                  ),
                ),
              ),

            // ── Mini Map (tappable markers) ─────────
            const SliverToBoxAdapter(
              child: SectionLabel(label: 'Peta Lokasi'),
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
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary),
                            ),
                          )
                        : MiniMapTappable(places: _places),
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
