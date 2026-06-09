import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import 'base_state.dart';

class LocationPickerStates extends Equatable {
  final LatLng? position; // The position that will be used for markers/initial map center
  final BaseState<String> addressData;
  final bool isMoving; // Track if the map is currently being dragged
  final bool shouldMoveToPosition; // Flag for programmatic map movement (e.g. initial load or 'My Location')
  final LatLng? currentCenter; // Track the current visual center of the map

  const LocationPickerStates({
    this.position,
    this.addressData = const BaseState(state: StatusState.initial),
    this.isMoving = false,
    this.shouldMoveToPosition = true,
    this.currentCenter,
  });

  LocationPickerStates copyWith({
    LatLng? position,
    BaseState<String>? addressData,
    bool? isMoving,
    bool? shouldMoveToPosition,
    LatLng? currentCenter,
  }) {
    return LocationPickerStates(
      position: position ?? this.position,
      addressData: addressData ?? this.addressData,
      isMoving: isMoving ?? this.isMoving,
      shouldMoveToPosition: shouldMoveToPosition ?? this.shouldMoveToPosition,
      currentCenter: currentCenter ?? this.currentCenter,
    );
  }

  @override
  List<Object?> get props => [
    position,
    addressData,
    isMoving,
    shouldMoveToPosition,
    currentCenter,
  ];
}
