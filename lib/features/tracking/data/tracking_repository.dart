import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class TrackingRepository {
  final Dio _dio;

  TrackingRepository({Dio? dio}) : _dio = dio ?? Dio();

  /// Fetches route coordinates between two LatLng locations using OSRM public routing API.
  Future<List<LatLng>> getRoutePoints(LatLng from, LatLng to) async {
    final url = 'http://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson';
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'] as Map<String, dynamic>?;
          if (geometry != null) {
            final coordinates = geometry['coordinates'] as List?;
            if (coordinates != null) {
              return coordinates.map((coord) {
                final lng = (coord[0] as num).toDouble();
                final lat = (coord[1] as num).toDouble();
                return LatLng(lat, lng);
              }).toList();
            }
          }
        }
      }
      throw Exception('Failed to load route points');
    } catch (e) {
      throw Exception('Failed to load route points: $e');
    }
  }

  /// Fetches route coordinates for a list of LatLng coordinates (multi-destination) using OSRM public routing API.
  Future<List<LatLng>> getRoutePointsList(List<LatLng> points) async {
    if (points.length < 2) return [];
    final coordsString = points.map((p) => '${p.longitude},${p.latitude}').join(';');
    final url = 'http://router.project-osrm.org/route/v1/driving/'
        '$coordsString'
        '?overview=full&geometries=geojson';
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'] as Map<String, dynamic>?;
          if (geometry != null) {
            final coordinates = geometry['coordinates'] as List?;
            if (coordinates != null) {
              return coordinates.map((coord) {
                final lng = (coord[0] as num).toDouble();
                final lat = (coord[1] as num).toDouble();
                return LatLng(lat, lng);
              }).toList();
            }
          }
        }
      }
      throw Exception('Failed to load route points');
    } catch (e) {
      throw Exception('Failed to load route points: $e');
    }
  }
}