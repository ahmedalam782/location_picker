## 1.0.3

- Fix: added required Android permissions (INTERNET, ACCESS_NETWORK_STATE, location) for release builds.
- Fix: network connectivity check now works in Android release builds (added network security config).
- Fix: SVG icon assets not loading after package rename (wrong `package:` reference).
- Fix: error message no longer shown as search bar hint text on offline/failure state.
- Added network and location permissions for iOS, macOS, and documentation for all platforms.
- Updated README with comprehensive platform-specific setup instructions.

## 1.0.2

- Published to pub.dev.
- Package renamed to `osm_location_picker`.
- Improved error widget: pull-to-refresh on mobile, retry button on web & desktop.
- Replaced `dart:io` Platform checks with `defaultTargetPlatform` for full web support.
- Added dartdoc to all public APIs.
- Switched license to MIT.

## 1.0.1+1

- Initial versioned release.
