import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'location_picker_failure.dart';

class LocationHelper {
  static final Map<String, String> _osmCache = {};
  static final Dio _dio = Dio();

  static String? getCachedPlaceName(double lat, double lng) {
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    return _osmCache[key];
  }

  static Future<String> getPlaceNameOSM(
    double lat,
    double lng, {
    String userAgent = 'LocationPicker/1.0',
  }) async {
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

    if (_osmCache.containsKey(key)) {
      final cachedValue = _osmCache[key]!;
      if (cachedValue != 'Unknown') {
        return cachedValue;
      }
    }

    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&accept-language=ar,en',
        options: Options(
          headers: {'User-Agent': userAgent, 'Accept-Language': 'ar,en'},
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      final data = response.data;
      String? address;
      if (data is Map) {
        address = data['display_name'] as String?;
      } else if (data is String) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map) {
            address = decoded['display_name'] as String?;
          }
        } catch (_) {}
      }

      final finalAddress = address ?? 'Unknown';
      _osmCache[key] = finalAddress;
      return finalAddress;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Position> getCurrentLocation({
    String serviceDisabledMsg = 'Location services are disabled.',
    String permissionDeniedMsg = 'Location permission denied.',
    String permissionPermanentlyDeniedMsg =
        'Location permission permanently denied.',
    String fetchFailedMsg = 'Failed to fetch location.',
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw GpsFailure(serviceDisabledMsg);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw GpsFailure(permissionDeniedMsg);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw GpsFailure(permissionPermanentlyDeniedMsg);
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return lastKnown;
        }
      } catch (_) {}
      throw GpsFailure(fetchFailedMsg);
    }
  }
}
