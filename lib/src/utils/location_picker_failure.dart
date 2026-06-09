class LocationPickerFailure implements Exception {
  final String errorMessage;
  const LocationPickerFailure(this.errorMessage);

  @override
  String toString() => errorMessage;
}

class OfflineFailure extends LocationPickerFailure {
  const OfflineFailure(super.errorMessage);
}

class GpsFailure extends LocationPickerFailure {
  const GpsFailure(super.errorMessage);
}
