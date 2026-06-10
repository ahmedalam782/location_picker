import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

class CarAnimationState extends Equatable {
  final LatLng currentPosition;
  final LatLng destination;
  final List<LatLng> allRoutePoints;
  final List<LatLng> passedPoints;
  final double bearing;
  final bool isFinished;
  final bool isAnimating;

  const CarAnimationState({
    required this.currentPosition,
    required this.destination,
    required this.allRoutePoints,
    required this.passedPoints,
    required this.bearing,
    required this.isFinished,
    required this.isAnimating,
  });

  factory CarAnimationState.initial() => CarAnimationState(
        currentPosition: const LatLng(0, 0),
        destination: const LatLng(0, 0),
        allRoutePoints: const [],
        passedPoints: const [],
        bearing: 0.0,
        isFinished: false,
        isAnimating: false,
      );

  List<LatLng> get remainingPoints {
    if (allRoutePoints.isEmpty) return [];
    final idx = allRoutePoints.indexWhere(
      (p) =>
          p.latitude == currentPosition.latitude &&
          p.longitude == currentPosition.longitude,
    );
    if (idx == -1) return allRoutePoints;
    return allRoutePoints.sublist(idx);
  }

  CarAnimationState copyWith({
    LatLng? currentPosition,
    LatLng? destination,
    List<LatLng>? allRoutePoints,
    List<LatLng>? passedPoints,
    double? bearing,
    bool? isFinished,
    bool? isAnimating,
  }) =>
      CarAnimationState(
        currentPosition: currentPosition ?? this.currentPosition,
        destination: destination ?? this.destination,
        allRoutePoints: allRoutePoints ?? this.allRoutePoints,
        passedPoints: passedPoints ?? this.passedPoints,
        bearing: bearing ?? this.bearing,
        isFinished: isFinished ?? this.isFinished,
        isAnimating: isAnimating ?? this.isAnimating,
      );

  @override
  List<Object?> get props => [
        currentPosition,
        destination,
        allRoutePoints,
        passedPoints,
        bearing,
        isFinished,
        isAnimating,
      ];
}
