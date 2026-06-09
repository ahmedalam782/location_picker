import 'package:latlong2/latlong.dart';

/// Holds the result of a location picker session.
///
/// Both [address] and [latLng] may be `null` if the user dismissed the picker
/// without confirming a location.
class LocationModel {
  /// Human-readable address string returned by the Nominatim reverse geocoder.
  final String? address;

  /// Geographic coordinates of the selected location.
  final LatLng? latLng;

  /// Creates a [LocationModel] with optional [address] and [latLng].
  const LocationModel({this.address, this.latLng});

  /// Deserialises a [LocationModel] from a JSON map.
  ///
  /// Accepts `latLng` encoded as either:
  /// - a `Map` with `latitude`/`lat` and `longitude`/`lng` keys, or
  /// - a two-element `List` `[latitude, longitude]`.
  factory LocationModel.fromJson(Map<String, dynamic> json) {
    final latLngJson = json['latLng'];
    LatLng? parsedLatLng;
    if (latLngJson is Map<String, dynamic>) {
      final lat = latLngJson['latitude'] ?? latLngJson['lat'];
      final lng = latLngJson['longitude'] ?? latLngJson['lng'];
      if (lat != null && lng != null) {
        parsedLatLng = LatLng(lat.toDouble(), lng.toDouble());
      }
    } else if (latLngJson is List && latLngJson.length == 2) {
      parsedLatLng = LatLng(latLngJson[0].toDouble(), latLngJson[1].toDouble());
    }
    return LocationModel(address: json['address'], latLng: parsedLatLng);
  }

  /// Serialises this model to a JSON map.
  Map<String, dynamic> toJson() => {
    'address': address,
    'latLng':
        latLng != null
            ? {'latitude': latLng!.latitude, 'longitude': latLng!.longitude}
            : null,
  };
}
