import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/scheduler.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'car_animation_state.dart';

class CarAnimationCubit extends Cubit<CarAnimationState> implements TickerProvider {
  AnimationController? _controller;
  int _currentIndex = 0;
  bool _isAnimating = false;

  CarAnimationCubit() : super(CarAnimationState.initial());

  @override
  Ticker createTicker(TickerCallback onTick) {
    return Ticker(onTick);
  }

  /// Start the route animation with a list of coordinate points.
  void startRoute(List<LatLng> points) {
    if (points.length < 2) return;
    _currentIndex = 0;
    _isAnimating = false;
    _controller?.dispose();
    _controller = null;

    emit(state.copyWith(
      allRoutePoints: points,
      currentPosition: points.first,
      destination: points.last,
      passedPoints: [points.first],
      bearing: 0.0,
      isFinished: false,
      isAnimating: true,
    ));

    _animateToNext(points);
  }

  /// Add a live point to the route (e.g. from live GPS).
  void addLivePoint(LatLng newPoint) {
    final updated = [...state.allRoutePoints, newPoint];
    emit(state.copyWith(allRoutePoints: updated));
    if (!_isAnimating) {
      _animateToNext(updated);
    }
  }

  void _animateToNext(List<LatLng> points) {
    if (_currentIndex >= points.length - 1) {
      _isAnimating = false;
      emit(state.copyWith(isFinished: true, isAnimating: false));
      return;
    }

    _isAnimating = true;
    final from = points[_currentIndex];
    final to = points[_currentIndex + 1];
    final bearing = _calcBearing(from, to);

    // Duration based on distance in meters.
    final distanceMeters = _calcDistance(from, to);
    final durationMs = (distanceMeters * 10).clamp(300, 2000).toInt();

    _controller?.dispose();
    _controller = null;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    // CurvedAnimation for natural movement flow.
    final animation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeInOut,
    );

    animation.addListener(() {
      final t = animation.value;
      final lat = lerpDouble(from.latitude, to.latitude, t) ?? from.latitude;
      final lng = lerpDouble(from.longitude, to.longitude, t) ?? from.longitude;
      final pos = LatLng(lat, lng);

      emit(state.copyWith(
        currentPosition: pos,
        bearing: bearing,
        passedPoints: [...state.passedPoints, pos],
      ));
    });

    _controller!.forward().whenComplete(() {
      _currentIndex++;
      // Recursively transition to the next segment.
      _animateToNext(state.allRoutePoints);
    });
  }

  /// Calculates the bearing angle between two LatLng positions in radians.
  double _calcBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final dLng = (to.longitude - from.longitude) * pi / 180;
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    return atan2(y, x);
  }

  /// Calculates the Haversine distance in meters.
  double _calcDistance(LatLng from, LatLng to) {
    const r = 6371000.0;
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final dLat = (to.latitude - from.latitude) * pi / 180;
    final dLng = (to.longitude - from.longitude) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Pauses/stops the route tracking animation.
  void stopRoute() {
    _controller?.stop();
    _isAnimating = false;
    emit(state.copyWith(isAnimating: false));
  }

  /// Resets the route to the initial state.
  void resetRoute() {
    _controller?.dispose();
    _controller = null;
    _currentIndex = 0;
    _isAnimating = false;
    emit(CarAnimationState.initial());
  }

  @override
  Future<void> close() {
    _controller?.dispose();
    _controller = null;
    return super.close();
  }
}
