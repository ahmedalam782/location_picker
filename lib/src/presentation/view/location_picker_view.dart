import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../location_picker_theme.dart';
import '../location_picker_strings.dart';
import '../view_model/cubit/location_picker_cubit.dart';
import 'widgets/location_picker_body.dart';

/// Full-screen location picker backed by OpenStreetMap.
///
/// Push this widget as a route and `await` the result. Returns a
/// [LocationModel] when the user confirms a location, or `null` when
/// dismissed.
///
/// ```dart
/// final result = await Navigator.of(context).push<LocationModel>(
///   MaterialPageRoute(builder: (_) => const LocationPickerView()),
/// );
/// ```
class LocationPickerView extends StatelessWidget {
  /// Pre-selected coordinates shown on the map when the picker opens.
  ///
  /// When `null` the picker tries to acquire the device's current GPS position.
  final LatLng? initialLatLng;

  /// Pre-selected address label shown in the header.
  final String? initialAddress;

  /// Visual theme. Defaults to [LocationPickerTheme.of] (derived from
  /// the ambient [ThemeData]) when not provided.
  final LocationPickerTheme? theme;

  /// UI text overrides. Defaults to [LocationPickerStrings.of] (locale-aware)
  /// when not provided.
  final LocationPickerStrings? strings;

  /// Creates a [LocationPickerView].
  const LocationPickerView({
    super.key,
    this.initialLatLng,
    this.initialAddress,
    this.theme,
    this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final activeTheme = theme ?? LocationPickerTheme.of(context);
    final activeStrings = strings ?? LocationPickerStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) {
        final cubit = LocationPickerCubit(
          initialLatLng: initialLatLng,
          initialAddress: initialAddress,
          strings: activeStrings,
        );
        final address = initialAddress;
        if (initialLatLng == null) {
          cubit.getCurrentLocation();
        } else if (address == null || address.isEmpty) {
          cubit.getAddressFromLatLng(initialLatLng!);
        }
        return cubit;
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: activeTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            ),
            titleSpacing: 0,
            title: Text(
              activeStrings.title,
              style: TextStyle(
                color: activeTheme.textDarkColor,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            centerTitle: false,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: activeTheme.textDarkColor,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: LocationPickerBody(theme: activeTheme, strings: activeStrings),
        ),
      ),
    );
  }
}
