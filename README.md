# osm_location_picker

[![pub package](https://img.shields.io/pub/v/osm_location_picker.svg?label=pub)](https://pub.dev/packages/osm_location_picker)
[![Flutter](https://img.shields.io/badge/Flutter-3.0.0%2B-02569B?logo=flutter)](https://flutter.dev/)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Web-brightgreen)](https://flutter.dev/multi-platform)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/ahmedalam782/osm_location_picker/blob/main/LICENSE)

A self-contained Flutter location picker powered by [OpenStreetMap](https://www.openstreetmap.org/).

> **No API key. No account. No billing.** Everything runs on free, open-source map and geocoding services — making this package a great fit for **small projects, prototypes, and indie apps** that don't want the overhead of registering with Google Maps or Mapbox.

Users can pan/zoom the map, search for addresses, and tap to confirm a location. The package returns a `LocationModel` containing the selected address string and `LatLng` coordinates.

## Features

- 🗺️ Interactive map using `flutter_map` + OpenStreetMap tiles
- 🔍 Address search powered by the Nominatim geocoding service
- 📍 Jump to the device's current GPS location with one tap
- 🎨 Fully themeable via `LocationPickerTheme`
- 🌐 Built-in Arabic and English UI strings — extend with `LocationPickerStrings`
- 🏗️ BLoC/Cubit state management — no global state pollution
- 📦 Zero external API keys needed

## Platform support

| Platform | Supported | Notes                                                  |
| -------- | --------- | ------------------------------------------------------ |
| Android  | ✅        | Full support                                           |
| iOS      | ✅        | Full support                                           |
| Web      | ✅        | Location uses browser Geolocation API — HTTPS required |
| macOS    | ✅        | Full support                                           |
| Windows  | ✅        | Full support                                           |
| Linux    | ✅        | Full support                                           |

> **Note:** GPS / current-location features depend on the [`location`](https://pub.dev/packages/location) package. On platforms where device location is unavailable or denied, the map still opens and the user can search or tap a location manually — so the picker always works regardless of permission status.

## Getting started

### 1. Add the dependency

```yaml
dependencies:
  osm_location_picker:
    path: ../ # or the pub.dev version once published
```

### 2. Platform permissions

#### Android — `android/app/src/main/AndroidManifest.xml`

Add these permissions **before** the `<application>` tag:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

> **Important for release builds:** The package checks internet connectivity before loading map tiles and performing geocoding searches. Both `INTERNET` and `ACCESS_NETWORK_STATE` permissions are required for the app to work properly in release mode.

#### iOS — `ios/Runner/Info.plist`

Add these keys inside the `<dict>` tag:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to your location to show it on the map.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to your location to show it on the map.</string>
```

> **Network access:** iOS allows network connections by default. For HTTP (non-HTTPS) connections, configure App Transport Security in Info.plist.

#### macOS — `macos/Runner/DebugProfile.entitlements` & `Release.entitlements`

Add network client and location entitlements inside the `<dict>` tag:

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.personal-information.location</key>
<true/>
```

For location access, also add to `macos/Runner/Info.plist`:

```xml
<key>NSLocationUsageDescription</key>
<string>This app needs access to your location to show it on the map.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to your location to show it on the map.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to your location to show it on the map.</string>
```

#### Web

No configuration needed. The package uses:

- Browser Geolocation API for GPS (requires **HTTPS** in production)
- OpenStreetMap tiles and Nominatim API (HTTPS)

> **Note:** HTTP-only domains will not have access to browser geolocation. Deploy with HTTPS or use `localhost` for development.

#### Windows & Linux

No additional permissions required. Network access is available by default.

## Usage

Push `LocationPickerView` as a full-screen route. It returns a `LocationModel?` when the user confirms a location.

```dart
import 'package:osm_location_picker/osm_location_picker.dart';

// Open the picker
final LocationModel? result = await Navigator.of(context).push<LocationModel>(
  MaterialPageRoute(
    builder: (_) => const LocationPickerView(),
  ),
);

if (result != null) {
  print(result.address);               // "Baghdad, Iraq"
  print(result.latLng?.latitude);      // 33.315241
  print(result.latLng?.longitude);     // 44.366085
}
```

### Restore a previously selected location

```dart
LocationPickerView(
  initialLatLng: LatLng(33.315241, 44.366085),
  initialAddress: 'Baghdad, Iraq',
)
```

### Custom theme

```dart
LocationPickerView(
  theme: LocationPickerTheme(
    primaryColor: Colors.teal,
    backgroundColor: Colors.white,
  ),
)
```

Use `LocationPickerTheme.of(context)` to derive colours from your app's `ThemeData` automatically.

### Custom strings / localisation

```dart
LocationPickerView(
  strings: LocationPickerStrings(
    title: 'Pick a spot',
    confirmLocation: 'Use this location',
    searchHint: 'Search address…',
    // … all fields required
  ),
)
```

Built-in factories: `LocationPickerStrings.en()` and `LocationPickerStrings.ar()`.
`LocationPickerStrings.of(context)` picks one automatically based on `Localizations.localeOf(context)`.

### `LocationModel`

| Field     | Type      | Description                           |
| --------- | --------- | ------------------------------------- |
| `address` | `String?` | Human-readable address from Nominatim |
| `latLng`  | `LatLng?` | Coordinates (`latlong2` package)      |

```dart
// Serialise / deserialise
final json = model.toJson();
final model2 = LocationModel.fromJson(json);
```

## Additional information

- Map tiles © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright)
- Geocoding provided by [Nominatim](https://nominatim.org/) — please respect the [usage policy](https://operations.osmfoundation.org/policies/nominatim/)
- File bugs and feature requests on the project's issue tracker
- Contributions are welcome — open a pull request with tests and a description of the change

## Troubleshooting

### macOS: "Failed to foreground app; open returned 1"
When running the application on macOS via `flutter run`, you may see this diagnostic warning. It is a known Flutter SDK behavior that occurs when the system cannot bring the app's window to the foreground (often because another window has focus, or when running with merged UI threads). If the application window launches successfully, this warning can be safely ignored.

