import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class RoutingService {
  static Future<Position> getCurrentLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'GPS tidak aktif. Aktifkan layanan lokasi di pengaturan perangkat.',
      );
    }
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

  static Future<List<LatLng>> getRouteFromOSRM(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    final uri = Uri.parse(
      '$osrmUrl'
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
    final coordinates = routes[0]['geometry']['coordinates'] as List;
    return coordinates
        .map((c) => LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ))
        .toList();
  }
}
