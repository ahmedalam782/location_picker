import 'package:latlong2/latlong.dart';

class RoutePoint {
  final double latitude;
  final double longitude;
  final String? name;

  const RoutePoint({
    required this.latitude,
    required this.longitude,
    this.name,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);
}
