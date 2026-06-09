import 'package:flutter/material.dart';

/// Localised UI strings used by [LocationPickerView].
///
/// Use [LocationPickerStrings.en] or [LocationPickerStrings.ar] for built-in
/// translations, or supply your own by constructing this class directly.
///
/// [LocationPickerStrings.of] automatically selects the correct locale based
/// on the ambient [BuildContext].
class LocationPickerStrings {
  /// Title displayed in the app bar.
  final String title;

  /// Shown while the device GPS position is being acquired.
  final String fetchingLocation;

  /// Shown when fetching the GPS position fails.
  final String locationFetchFailed;

  /// Placeholder address when reverse geocoding returns nothing.
  final String unknownLocation;

  /// Label for the confirm-location action button.
  final String confirmLocation;

  /// Label for the "my location" / GPS button.
  final String currentLocation;

  /// Shown when the device has no internet connection.
  final String noInternet;

  /// Shown when the device location service is disabled.
  final String serviceDisabled;

  /// Shown when location permission has been denied.
  final String permissionDenied;

  /// Shown when location permission has been permanently denied.
  final String permissionPermanentlyDenied;

  /// Placeholder hint inside the address search field.
  final String searchHint;

  /// Shown when an address search returns no results.
  final String noResults;

  /// Creates a [LocationPickerStrings] with all fields required.
  const LocationPickerStrings({
    required this.title,
    required this.fetchingLocation,
    required this.locationFetchFailed,
    required this.unknownLocation,
    required this.confirmLocation,
    required this.currentLocation,
    required this.noInternet,
    required this.serviceDisabled,
    required this.permissionDenied,
    required this.permissionPermanentlyDenied,
    required this.searchHint,
    required this.noResults,
  });

  /// Returns Arabic (العربية) UI strings.
  factory LocationPickerStrings.ar() => const LocationPickerStrings(
    title: 'تحديد الموقع',
    fetchingLocation: 'جاري جلب الموقع...',
    locationFetchFailed: 'فشل جلب الموقع',
    unknownLocation: 'موقع غير معروف',
    confirmLocation: 'تأكيد الموقع',
    currentLocation: 'الموقع الحالي',
    noInternet: 'لا يوجد اتصال بالإنترنت، يرجى المحاولة مرة أخرى!',
    serviceDisabled: 'خدمات الموقع معطلة',
    permissionDenied: 'تم رفض إذن الوصول للموقع',
    permissionPermanentlyDenied: 'تم رفض إذن الوصول للموقع بشكل دائم',
    searchHint: 'ابحث عن موقع...',
    noResults: 'لا توجد نتائج',
  );

  /// Returns English UI strings.
  factory LocationPickerStrings.en() => const LocationPickerStrings(
    title: 'Select Location',
    fetchingLocation: 'Fetching location...',
    locationFetchFailed: 'Failed to fetch location',
    unknownLocation: 'Unknown location',
    confirmLocation: 'Confirm Location',
    currentLocation: 'Current Location',
    noInternet: 'No internet connection, please try again!',
    serviceDisabled: 'Location services are disabled',
    permissionDenied: 'Location permission denied',
    permissionPermanentlyDenied: 'Location permission permanently denied',
    searchHint: 'Search for a location...',
    noResults: 'No results found',
  );

  /// Returns the appropriate strings for the ambient locale.
  ///
  /// Falls back to [LocationPickerStrings.en] for any locale other than `ar`.
  factory LocationPickerStrings.of(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return languageCode == 'ar'
        ? LocationPickerStrings.ar()
        : LocationPickerStrings.en();
  }
}
