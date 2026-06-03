import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/place.dart';
import '../screens/place_detail_screen.dart';
import 'shared_widgets.dart';

// ──────────────────────────────────────────────
// MINI MAP with tappable markers → detail screen
// ──────────────────────────────────────────────

class MiniMapTappable extends StatefulWidget {
  final List<Place> places;
  const MiniMapTappable({required this.places});

  @override
  State<MiniMapTappable> createState() => _MiniMapTappableState();
}

class _MiniMapTappableState extends State<MiniMapTappable> {
  @override
  Widget build(BuildContext context) {
    final validPlaces = widget.places
        .where((p) => p.latitude != 0 && p.longitude != 0)
        .toList();
    final center = validPlaces.isNotEmpty
        ? LatLng(validPlaces[0].latitude, validPlaces[0].longitude)
        : const LatLng(-7.2575, 112.7521);

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 14),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.laundry_app',
        ),
        MarkerLayer(
          markers: validPlaces
              .map((p) => Marker(
                    point: LatLng(p.latitude, p.longitude),
                    width: 44,
                    height: 52,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaceDetailScreen(place: p),
                        ),
                      ),
                      child: const MapPin(),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
