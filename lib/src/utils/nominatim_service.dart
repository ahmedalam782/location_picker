import 'package:dio/dio.dart';

/// A single result returned by the Nominatim geocoding API.
class NominatimSearchResult {
  /// Full display name of the matched location.
  final String displayName;

  /// Latitude of the matched location.
  final double lat;

  /// Longitude of the matched location.
  final double lon;

  /// OSM type string (e.g. `"city"`, `"road"`).
  final String type;

  /// Creates a [NominatimSearchResult].
  const NominatimSearchResult({
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.type,
  });

  /// Deserialises a [NominatimSearchResult] from a Nominatim JSON object.
  factory NominatimSearchResult.fromJson(Map<String, dynamic> json) {
    return NominatimSearchResult(
      displayName: json['display_name'] as String? ?? '',
      lat: double.tryParse(json['lat'] as String? ?? '0') ?? 0.0,
      lon: double.tryParse(json['lon'] as String? ?? '0') ?? 0.0,
      type: json['type'] as String? ?? '',
    );
  }
}

/// Thin wrapper around the [Nominatim](https://nominatim.org/) search API.
///
/// Requires no API key. Please respect the
/// [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/).
class NominatimService {
  final Dio _dio;

  /// Creates a [NominatimService] backed by the provided [Dio] instance.
  NominatimService(this._dio);

  /// Searches for locations matching [query].
  ///
  /// Returns an empty list when [query] is blank or on network failure.
  /// Results are limited to 5 entries.
  Future<List<NominatimSearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 5,
          'addressdetails': 1,
        },
        options: Options(
          headers: {
            'Accept-Language': 'ar,en',
            'User-Agent': 'LocationPicker/1.0',
          },
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      final list = response.data;
      if (list is List) {
        return list
            .map(
              (e) => NominatimSearchResult.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
