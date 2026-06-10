/// A self-contained Flutter location picker powered by OpenStreetMap.
///
/// No API key is required. Users can pan/zoom the map, search for addresses,
/// and confirm a location. The package returns a [LocationModel] with the
/// selected address and [LatLng] coordinates.
///
/// ## Usage
/// ```dart
/// final result = await Navigator.of(context).push<LocationModel>(
///   MaterialPageRoute(builder: (_) => const LocationPickerView()),
/// );
/// ```
library;

export 'src/models/location_model.dart';
export 'src/presentation/location_picker_strings.dart';
export 'src/presentation/location_picker_theme.dart';
export 'src/presentation/view/location_picker_view.dart';
export 'src/utils/nominatim_service.dart';
export 'features/tracking/domain/models/route_point.dart';
export 'features/tracking/data/tracking_repository.dart';
export 'features/tracking/presentation/cubit/car_animation_cubit.dart';
export 'features/tracking/presentation/cubit/car_animation_state.dart';
export 'features/tracking/presentation/screens/car_map_screen.dart';
export 'injection_container.dart';
export 'app_router.dart';
