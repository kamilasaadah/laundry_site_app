import 'package:flutter/material.dart';
import '../models/place.dart';
import '../services/api_service.dart';
import '../services/favorites_service.dart';
import '../utils/constants.dart';
import '../widgets/place_card.dart';
import '../widgets/shared_widgets.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with AutomaticKeepAliveClientMixin {
  List<Place> _favPlaces = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFavorites();
    }
  }

  Future<void> _loadFavorites() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final favIds = await FavoritesService.getFavorites();
      if (favIds.isEmpty) {
        if (mounted) {
          setState(() {
            _favPlaces = [];
            _loading = false;
          });
        }
        return;
      }
      final allPlaces = await ApiService.fetchPlaces();
      if (mounted) {
        setState(() {
          _favPlaces =
              allPlaces.where((p) => favIds.contains(p.id)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Favorit'),
            if (!_loading && _error == null)
              Text(
                '${_favPlaces.length} tempat laundry tersimpan',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFavorites,
            color: AppColors.primary,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadFavorites,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? AppErrorWidget(message: _error!, onRetry: _loadFavorites)
                : _favPlaces.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.favorite_border_rounded,
                                      size: 40,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Belum ada favorit',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 40),
                                    child: Text(
                                      'Ketuk ikon ♡ pada kartu laundry untuk menyimpannya di sini',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          const SectionLabel(
                              label: 'Tersimpan', leftPad: 0),
                          ..._favPlaces.map((p) => PlaceCardLarge(
                                place: p,
                                onFavoriteChanged: _loadFavorites,
                              )),
                        ],
                      ),
      ),
    );
  }
}
