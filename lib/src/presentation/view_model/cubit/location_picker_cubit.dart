import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'base_state.dart';
import 'safe_emit_mixin.dart';
import 'location_picker_states.dart';
import '../../../utils/location_helper.dart';
import '../../../utils/location_picker_failure.dart';
import '../../location_picker_strings.dart';

class LocationPickerCubit extends Cubit<LocationPickerStates>
    with SafeEmitMixin<LocationPickerStates> {
  static const LatLng _fallbackLatLng = LatLng(33.3152, 44.3661);
  final LocationPickerStrings strings;

  LocationPickerCubit({
    LatLng? initialLatLng,
    String? initialAddress,
    required this.strings,
  }) : super(
         LocationPickerStates(
           position: initialLatLng,
           currentCenter: initialLatLng ?? _fallbackLatLng,
           addressData: BaseState(
             state: (initialLatLng != null && initialAddress != null)
                 ? StatusState.success
                 : StatusState.initial,
             data: initialAddress,
           ),
         ),
       );

  Future<void> getCurrentLocation({LatLng? position}) async {
    // If position is provided, check the cache first to avoid showing loading spinner
    if (position != null) {
      final cachedAddress = LocationHelper.getCachedPlaceName(
        position.latitude,
        position.longitude,
      );

      if (cachedAddress != null) {
        emit(
          state.copyWith(
            position: position,
            currentCenter: position,
            shouldMoveToPosition: true,
            isMoving: false,
            addressData: BaseState(
              state: StatusState.success,
              data: cachedAddress,
            ),
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          position: position,
          currentCenter: position,
          shouldMoveToPosition: true,
          isMoving: false,
          addressData: const BaseState(state: StatusState.loading),
        ),
      );
      getAddressFromLatLng(position);
      return;
    }

    emit(
      state.copyWith(
        addressData: const BaseState(state: StatusState.loading),
        shouldMoveToPosition: false,
        isMoving: false,
      ),
    );

    try {
      final res = await LocationHelper.getCurrentLocation(
        serviceDisabledMsg: strings.serviceDisabled,
        permissionDeniedMsg: strings.permissionDenied,
        permissionPermanentlyDeniedMsg: strings.permissionPermanentlyDenied,
        fetchFailedMsg: strings.locationFetchFailed,
      );

      final latLng = LatLng(res.latitude, res.longitude);

      // Check cache first to avoid flashing loading state
      final cachedAddress = LocationHelper.getCachedPlaceName(
        latLng.latitude,
        latLng.longitude,
      );

      if (cachedAddress != null) {
        emit(
          state.copyWith(
            position: latLng,
            currentCenter: latLng,
            shouldMoveToPosition: true,
            addressData: BaseState(
              state: StatusState.success,
              data: cachedAddress,
            ),
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          position: latLng,
          currentCenter: latLng,
          shouldMoveToPosition: true,
          addressData: state.addressData.copyWith(state: StatusState.loading),
        ),
      );

      getAddressFromLatLng(latLng);
    } catch (error) {
      final fallbackPosition =
          state.currentCenter ?? state.position ?? _fallbackLatLng;

      // Automatically fallback to manual selection mode centered at the fallback position
      getAddressFromLatLng(fallbackPosition);
    }
  }

  void onCameraMove(LatLng position) {
    emit(state.copyWith(currentCenter: position, isMoving: true));
  }

  void onCameraIdle() {
    if (state.isMoving && state.currentCenter != null) {
      emit(state.copyWith(isMoving: false));

      // If we already have or are loading the address for the target position,
      // and the camera stopped close to it (same cache key), do not trigger another fetch.
      if (state.position != null) {
        final targetKey =
            '${state.position!.latitude.toStringAsFixed(4)},${state.position!.longitude.toStringAsFixed(4)}';
        final currentKey =
            '${state.currentCenter!.latitude.toStringAsFixed(4)},${state.currentCenter!.longitude.toStringAsFixed(4)}';
        if (targetKey == currentKey &&
            (state.addressData.state == StatusState.success ||
                state.addressData.state == StatusState.loading)) {
          return;
        }
      }

      getAddressFromLatLng(state.currentCenter!);
    }
  }

  void updateShouldMoveToPosition(bool value) {
    emit(state.copyWith(shouldMoveToPosition: value));
  }

  Future<void> getAddressFromLatLng(LatLng position) async {
    // Check if the address is already in the cache first to avoid showing the loader and network check
    final cachedAddress = LocationHelper.getCachedPlaceName(
      position.latitude,
      position.longitude,
    );

    if (cachedAddress != null) {
      emit(
        state.copyWith(
          position: position,
          currentCenter: position,
          addressData: BaseState(
            state: StatusState.success,
            data: cachedAddress,
          ),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        position: position,
        currentCenter: position,
        addressData: const BaseState(state: StatusState.loading),
      ),
    );

    // Check for internet connection
    final isConnected = await InternetConnection().hasInternetAccess;
    if (!isConnected) {
      emit(
        state.copyWith(
          position: position,
          currentCenter: position,
          addressData: BaseState(
            state: StatusState.failure,
            exception: OfflineFailure(strings.noInternet),
          ),
        ),
      );
      return;
    }

    try {
      final address = await LocationHelper.getPlaceNameOSM(
        position.latitude,
        position.longitude,
      );
      emit(
        state.copyWith(
          position: position,
          currentCenter: position,
          addressData: BaseState(
            state: StatusState.success,
            data: (address != "Unknown" && address.isNotEmpty)
                ? address
                : state.addressData.data,
          ),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          position: position,
          currentCenter: position,
          addressData: BaseState(
            state: StatusState.failure,
            exception: LocationPickerFailure(strings.locationFetchFailed),
          ),
        ),
      );
    }
  }

  void selectLocation(LatLng position, String address) {
    emit(
      state.copyWith(
        position: position,
        currentCenter: position,
        shouldMoveToPosition: true,
        isMoving: false,
        addressData: BaseState(state: StatusState.success, data: address),
      ),
    );
  }

  void dismissError() {
    final fallbackPosition =
        state.currentCenter ?? state.position ?? _fallbackLatLng;
    emit(
      state.copyWith(
        position: fallbackPosition,
        currentCenter: fallbackPosition,
        shouldMoveToPosition: true,
        isMoving: false,
        addressData: BaseState(
          state: StatusState.success,
          data: state.addressData.data ?? strings.unknownLocation,
        ),
      ),
    );
  }
}
