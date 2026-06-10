import 'package:go_router/go_router.dart';
import 'features/tracking/presentation/screens/car_map_screen.dart';

final goRouter = GoRouter(
  initialLocation: '/car-tracking',
  routes: [
    GoRoute(
      path: '/car-tracking',
      builder: (context, state) => const CarMapScreen(),
    ),
  ],
);
