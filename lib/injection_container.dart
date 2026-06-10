import 'package:get_it/get_it.dart';
import 'features/tracking/data/tracking_repository.dart';
import 'features/tracking/data/socket_tracking_service.dart';

final sl = GetIt.instance;

Future<void> initDI() async {
  sl.registerLazySingleton<TrackingRepository>(() => TrackingRepository());
  sl.registerLazySingleton<SocketTrackingService>(() => SocketTrackingService());
}
