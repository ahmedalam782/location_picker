import 'package:flutter/material.dart';

/// Visual configuration for [LocationPickerView].
///
/// All colours have sensible defaults (red accent on white). Use
/// [LocationPickerTheme.of] to derive colours automatically from the app's
/// [ThemeData], or construct this class directly for full control.
class LocationPickerTheme {
  /// Primary accent colour used for buttons, the confirm bar, and the pin.
  final Color primaryColor;

  /// Scaffold / map overlay background colour.
  final Color backgroundColor;

  /// Card surface colour (search bar, address header, etc.).
  final Color cardColor;

  /// Border colour for cards and input fields.
  final Color borderColor;

  /// Primary text colour (on light surfaces).
  final Color textDarkColor;

  /// Secondary text colour (on dark / coloured surfaces).
  final Color textLightColor;

  /// Shadow applied to floating cards.
  final BoxShadow shadowBox;

  /// Shadow applied to FABs.
  final BoxShadow fabShadow;

  /// Optional Lottie asset path shown while the location is loading.
  final String? loadingLottieAsset;

  /// Optional Lottie asset path shown on a generic error state.
  final String? errorLottieAsset;

  /// Optional Lottie asset path shown when the device is offline.
  final String? noInternetLottieAsset;

  /// Creates a [LocationPickerTheme] with optional overrides.
  ///
  /// All fields have defaults so you only need to pass the values you want
  /// to change.
  const LocationPickerTheme({
    this.primaryColor = const Color(0xffEA3433),
    this.backgroundColor = const Color(0xffFDF2F2),
    this.cardColor = const Color(0xffffffff),
    this.borderColor = const Color(0xffFCD6D6),
    this.textDarkColor = const Color(0xff0A100B),
    this.textLightColor = const Color(0xffffffff),
    this.shadowBox = const BoxShadow(
      color: Color(0x0D000000), // originalBlack with 0.05 alpha
      blurRadius: 10,
      spreadRadius: 1,
      offset: Offset(0, 0),
    ),
    this.fabShadow = const BoxShadow(
      color: Color(0x14000000), // originalBlack with 0.08 alpha
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
    this.loadingLottieAsset,
    this.errorLottieAsset,
    this.noInternetLottieAsset,
  });

  /// Returns a copy of this theme with the given fields replaced.
  LocationPickerTheme copyWith({
    Color? primaryColor,
    Color? backgroundColor,
    Color? cardColor,
    Color? borderColor,
    Color? textDarkColor,
    Color? textLightColor,
    BoxShadow? shadowBox,
    BoxShadow? fabShadow,
    String? loadingLottieAsset,
    String? errorLottieAsset,
    String? noInternetLottieAsset,
  }) {
    return LocationPickerTheme(
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      cardColor: cardColor ?? this.cardColor,
      borderColor: borderColor ?? this.borderColor,
      textDarkColor: textDarkColor ?? this.textDarkColor,
      textLightColor: textLightColor ?? this.textLightColor,
      shadowBox: shadowBox ?? this.shadowBox,
      fabShadow: fabShadow ?? this.fabShadow,
      loadingLottieAsset: loadingLottieAsset ?? this.loadingLottieAsset,
      errorLottieAsset: errorLottieAsset ?? this.errorLottieAsset,
      noInternetLottieAsset:
          noInternetLottieAsset ?? this.noInternetLottieAsset,
    );
  }

  /// Derives a [LocationPickerTheme] from the ambient [BuildContext]'s
  /// [ThemeData], automatically adapting to dark/light mode.
  factory LocationPickerTheme.of(
    BuildContext context, {
    String? loadingLottieAsset,
    String? errorLottieAsset,
    String? noInternetLottieAsset,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LocationPickerTheme(
      primaryColor: Theme.of(context).primaryColor,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      cardColor: isDark ? const Color(0xff0A100B) : const Color(0xffffffff),
      borderColor:
          isDark
              ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
              : Theme.of(context).primaryColor.withValues(alpha: 0.15),
      textDarkColor: isDark ? const Color(0xffffffff) : const Color(0xff0A100B),
      textLightColor:
          isDark ? const Color(0xff0A100B) : const Color(0xffffffff),
      loadingLottieAsset: loadingLottieAsset,
      errorLottieAsset: errorLottieAsset,
      noInternetLottieAsset: noInternetLottieAsset,
    );
  }
}
