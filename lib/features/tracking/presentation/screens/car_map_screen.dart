import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:convert';
import '../../../../src/presentation/location_picker_strings.dart';
import '../../../../injection_container.dart';
import '../../data/tracking_repository.dart';
import '../../data/socket_tracking_service.dart';
import '../cubit/car_animation_cubit.dart';
import '../cubit/car_animation_state.dart';

enum MapMode { tracking, rideHailing, explorer, socket }

class CarMapScreen extends StatelessWidget {
  const CarMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CarAnimationCubit(),
      child: const _CarMapBody(),
    );
  }
}

class _CarMapBody extends StatefulWidget {
  const _CarMapBody();

  @override
  State<_CarMapBody> createState() => _CarMapBodyState();
}

class _CarMapBodyState extends State<_CarMapBody> {
  late final MapController _mapController;
  MapMode _activeMode = MapMode.tracking;

  // Car Routing properties (Multi-destination)
  final List<LatLng> _waypoints = [];
  List<LatLng> _routePoints = [];
  bool _isFetchingRoute = false;

  // Ride Hailing Simulation properties
  LatLng? _driverPoint;
  LatLng? _customerPoint;
  LatLng? _destinationPointRide;
  List<LatLng> _pickupRoutePoints = [];
  List<LatLng> _tripRoutePoints = [];
  bool _isFetchingRideRoute = false;
  String _ridePhase = 'idle'; // 'idle', 'fetching', 'pickup', 'trip', 'finished'

  // Country Explorer properties
  final TextEditingController _searchController = TextEditingController();
  List<Polygon> _countryPolygons = [];
  bool _isSearchingCountry = false;
  Map<String, dynamic>? _countryDetails;
  String _countryExplanation = '';

  // Live Socket tracking properties
  final TextEditingController _socketUrlController = TextEditingController(text: 'mock://realtime');
  SocketConnectionState _socketConnectionState = SocketConnectionState.disconnected;
  final List<String> _socketLogs = [];
  double _socketSpeed = 0.0;
  int _socketBattery = 100;
  int _socketPacketCount = 0;
  StreamSubscription<String>? _socketMessageSub;
  StreamSubscription<SocketConnectionState>? _socketStatusSub;
  bool _isSocketSimulatorStarting = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _socketUrlController.dispose();
    _socketMessageSub?.cancel();
    _socketStatusSub?.cancel();
    super.dispose();
  }

  Future<void> _connectSocket() async {
    final service = sl<SocketTrackingService>();
    final url = _socketUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _socketConnectionState = SocketConnectionState.connecting;
    });

    try {
      await _socketMessageSub?.cancel();
      await _socketStatusSub?.cancel();

      // Listen for incoming messages
      _socketMessageSub = service.messagesStream.listen((msg) {
        _handleSocketMessage(msg);
      });

      // Listen for connection status updates
      _socketStatusSub = service.connectionStateStream.listen((status) {
        if (mounted) {
          setState(() {
            _socketConnectionState = status;
          });
        }
      });

      await service.connect(url);
    } catch (e) {
      _showErrorSnackBar('Socket connection error: $e');
      if (mounted) {
        setState(() {
          _socketConnectionState = SocketConnectionState.disconnected;
        });
      }
    }
  }

  Future<void> _disconnectSocket() async {
    final service = sl<SocketTrackingService>();
    await service.disconnect();
    await _socketMessageSub?.cancel();
    await _socketStatusSub?.cancel();
    _socketMessageSub = null;
    _socketStatusSub = null;

    if (mounted) {
      setState(() {
        _socketConnectionState = SocketConnectionState.disconnected;
        _socketSpeed = 0.0;
        _socketBattery = 100;
      });
    }
  }

  void _handleSocketMessage(String msg) {
    if (!mounted) return;

    setState(() {
      _socketPacketCount++;
      _socketLogs.insert(0, '[${DateTime.now().toString().substring(11, 19)}] Rx: $msg');
      if (_socketLogs.length > 50) {
        _socketLogs.removeLast();
      }
    });

    try {
      final data = jsonDecode(msg) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'location') {
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        final speed = (data['speed'] as num?)?.toDouble() ?? 0.0;
        final battery = data['battery'] as int? ?? 100;

        if (lat != null && lng != null) {
          final point = LatLng(lat, lng);
          setState(() {
            _socketSpeed = speed;
            _socketBattery = battery;
          });
          
          // Animate car to the live coordinate using addLivePoint in cubit
          context.read<CarAnimationCubit>().addLivePoint(point);
          // Center the map on the vehicle's new position
          _mapController.move(point, _mapController.camera.zoom);
        }
      } else if (type == 'system_log') {
        final message = data['message'] as String? ?? '';
        final logType = data['log_type'] as String? ?? 'Info';
        debugPrint('[$logType] $message');
      } else if (type == 'system_error') {
        final errorMsg = data['message'] as String? ?? 'Unknown error';
        _showErrorSnackBar('Socket Error: $errorMsg');
      }
    } catch (e) {
      debugPrint('Error parsing socket packet: $e');
    }
  }

  Future<void> _startSocketMockSimulation() async {
    if (_waypoints.length < 2) {
      _showErrorSnackBar('Please tap the map to add at least 2 waypoints for routing.');
      return;
    }

    setState(() {
      _isSocketSimulatorStarting = true;
    });

    try {
      final trackingRepo = sl<TrackingRepository>();
      final points = await trackingRepo.getRoutePointsList(_waypoints);

      if (points.isNotEmpty) {
        // Ensure connected to mock socket
        if (_socketConnectionState != SocketConnectionState.connected) {
          await _connectSocket();
        }

        if (!mounted) return;

        // Initialize/reset route points and passed points in the cubit
        context.read<CarAnimationCubit>().startRoute([points.first, points.first]);
        context.read<CarAnimationCubit>().stopRoute(); // Stop internal animation controller loop

        // Start transmitting coordinates over the WebSocket stream
        sl<SocketTrackingService>().startMockSimulation(points);
      } else {
        _showErrorSnackBar('Failed to fetch route coordinates for simulation.');
      }
    } catch (e) {
      _showErrorSnackBar('Error starting simulation: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSocketSimulatorStarting = false;
        });
      }
    }
  }


  // --- Reset All States when switching modes ---
  void _resetAllStates([MapMode? newMode]) {
    context.read<CarAnimationCubit>().resetRoute();
    _disconnectSocket();
    setState(() {
      if (newMode != null) {
        _activeMode = newMode;
      }
      _waypoints.clear();
      _routePoints = [];
      _driverPoint = null;
      _customerPoint = null;
      _destinationPointRide = null;
      _pickupRoutePoints = [];
      _tripRoutePoints = [];
      _ridePhase = 'idle';
      _isFetchingRoute = false;
      _isFetchingRideRoute = false;
      _countryPolygons = [];
      _countryDetails = null;
      _countryExplanation = '';
      _searchController.clear();
      _socketLogs.clear();
      _socketSpeed = 0.0;
      _socketBattery = 100;
      _socketPacketCount = 0;
    });
  }

  // --- OSRM Route Fetching (Multi-destination support) ---
  Future<void> _fetchAndStartRoute() async {
    if (_waypoints.length < 2) return;

    setState(() {
      _isFetchingRoute = true;
    });

    try {
      final trackingRepo = sl<TrackingRepository>();
      final points = await trackingRepo.getRoutePointsList(_waypoints);

      if (points.isNotEmpty) {
        setState(() {
          _routePoints = points;
        });
        if (mounted) {
          context.read<CarAnimationCubit>().startRoute(points);
        }
      } else {
        _showErrorSnackBar('No route points returned from server.');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to fetch route coordinates: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingRoute = false;
        });
      }
    }
  }

  // --- OSRM Ride Hailing Route Fetching (Driver -> Customer & Customer -> Destination) ---
  Future<void> _fetchRideRoutes() async {
    if (_driverPoint == null || _customerPoint == null || _destinationPointRide == null) return;

    setState(() {
      _isFetchingRideRoute = true;
      _ridePhase = 'fetching';
    });

    try {
      final trackingRepo = sl<TrackingRepository>();
      
      // Fetch Pickup Route (Driver to Customer)
      final pickupPoints = await trackingRepo.getRoutePoints(_driverPoint!, _customerPoint!);
      
      // Fetch Trip Route (Customer to Destination)
      final tripPoints = await trackingRepo.getRoutePoints(_customerPoint!, _destinationPointRide!);

      if (pickupPoints.isNotEmpty && tripPoints.isNotEmpty) {
        setState(() {
          _pickupRoutePoints = pickupPoints;
          _tripRoutePoints = tripPoints;
          _ridePhase = 'idle';
        });
      } else {
        _showErrorSnackBar('Failed to fetch complete ride routes.');
        setState(() { _ridePhase = 'idle'; });
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching ride routes: $e');
      setState(() { _ridePhase = 'idle'; });
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingRideRoute = false;
        });
      }
    }
  }

  void _startRideSimulation() {
    if (_pickupRoutePoints.isEmpty || _tripRoutePoints.isEmpty) return;

    setState(() {
      _ridePhase = 'pickup';
    });

    context.read<CarAnimationCubit>().startRoute(_pickupRoutePoints);
  }

  // --- Nominatim Country Polygon Search ---
  Future<void> _searchCountryPolygon(String countryName) async {
    if (countryName.trim().isEmpty) return;

    setState(() {
      _isSearchingCountry = true;
      _countryPolygons = [];
      _countryDetails = null;
      _countryExplanation = '';
    });

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': countryName,
          'format': 'json',
          'polygon_geojson': 1,
          'limit': 1,
          'addressdetails': 1,
        },
        options: Options(
          headers: {
            'User-Agent': 'OsmLocationPicker/1.0',
            'Accept-Language': 'en',
          },
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data is List && (response.data as List).isNotEmpty) {
        final result = response.data[0] as Map<String, dynamic>;
        final geojson = result['geojson'] as Map<String, dynamic>?;
        final lat = double.tryParse(result['lat']?.toString() ?? '') ?? 0.0;
        final lon = double.tryParse(result['lon']?.toString() ?? '') ?? 0.0;
        final boundingBox = result['boundingbox'] as List?;

        if (geojson != null) {
          final parsed = _parseGeoJson(geojson);
          if (parsed.isNotEmpty) {
            setState(() {
              _countryPolygons = parsed;
              _countryDetails = result;
              _countryExplanation = _generateCountryExplanation(result, lat, lon, boundingBox);
            });

            // Center map on the country centroid
            _mapController.move(LatLng(lat, lon), 5.0);
          } else {
            _showErrorSnackBar('Country boundary geometry could not be parsed.');
          }
        } else {
          _showErrorSnackBar('No boundary geometry found for "$countryName".');
        }
      } else {
        _showErrorSnackBar('Country "$countryName" not found.');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to search country boundaries: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingCountry = false;
        });
      }
    }
  }

  // --- GeoJSON Polygon/MultiPolygon Parser ---
  List<Polygon> _parseGeoJson(Map<String, dynamic> geojson) {
    final type = geojson['type'] as String?;
    final coordinates = geojson['coordinates'] as List?;
    if (coordinates == null) return [];

    final List<Polygon> parsedPolygons = [];
    final fillColor = const Color(0xff185FA5).withValues(alpha: 0.18);
    final borderColor = const Color(0xff185FA5);

    if (type == 'Polygon') {
      for (final ring in coordinates) {
        final points = (ring as List).map((p) {
          final lng = (p[0] as num).toDouble();
          final lat = (p[1] as num).toDouble();
          return LatLng(lat, lng);
        }).toList();
        if (points.isNotEmpty) {
          parsedPolygons.add(
            Polygon(
              points: points,
              color: fillColor,
              borderColor: borderColor,
              borderStrokeWidth: 2.5,
            ),
          );
        }
      }
    } else if (type == 'MultiPolygon') {
      for (final poly in coordinates) {
        for (final ring in poly as List) {
          final points = (ring as List).map((p) {
            final lng = (p[0] as num).toDouble();
            final lat = (p[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();
          if (points.isNotEmpty) {
            parsedPolygons.add(
              Polygon(
                points: points,
                color: fillColor,
                borderColor: borderColor,
                borderStrokeWidth: 2.5,
              ),
            );
          }
        }
      }
    }
    return parsedPolygons;
  }

  // --- Helper to Generate a Country boundary explanation ---
  String _generateCountryExplanation(Map<String, dynamic> result, double lat, double lon, List? bbox) {
    final displayName = result['display_name'] ?? 'Unknown Country';
    final type = result['type'] ?? 'boundary';
    final osmType = result['osm_type'] ?? 'relation';

    String bboxStr = '';
    if (bbox != null && bbox.length == 4) {
      bboxStr = '\n• Bounding Box: ${bbox[0]} to ${bbox[1]} Latitude, ${bbox[2]} to ${bbox[3]} Longitude.';
    }

    return 'This boundary is represented in OpenStreetMap as an OSM $osmType ($type category).\n'
        '• Centroid Coordinate: Lat ${lat.toStringAsFixed(4)}, Lon ${lon.toStringAsFixed(4)}.$bboxStr\n'
        '• OSM Source Name: $displayName';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearCountryState() {
    setState(() {
      _countryPolygons = [];
      _countryDetails = null;
      _countryExplanation = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocationPickerStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _activeMode == MapMode.tracking 
              ? 'Car Routing' 
              : (_activeMode == MapMode.rideHailing ? 'Ride Hailing' : 'Country Explorer')
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<CarAnimationCubit, CarAnimationState>(
        listener: (context, state) {
          if (state.isFinished && _activeMode == MapMode.rideHailing) {
            if (_ridePhase == 'pickup') {
              // Pickup reached! Start Trip phase
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Picked up customer! Starting trip to destination...'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 3),
                ),
              );
              setState(() {
                _ridePhase = 'trip';
              });
              context.read<CarAnimationCubit>().startRoute(_tripRoutePoints);
            } else if (_ridePhase == 'trip') {
              // Trip finished!
              setState(() {
                _ridePhase = 'finished';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Arrived at destination! Trip completed successfully.'),
                  backgroundColor: Colors.blue,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        builder: (context, state) {
          LatLng initialCenter = const LatLng(30.0444, 31.2357);
          if (_activeMode == MapMode.tracking && _waypoints.isNotEmpty) {
            initialCenter = _waypoints.first;
          } else if (_activeMode == MapMode.rideHailing && _driverPoint != null) {
            initialCenter = _driverPoint!;
          } else if (_activeMode == MapMode.socket && state.currentPosition.latitude != 0) {
            initialCenter = state.currentPosition;
          } else if (_activeMode == MapMode.socket && _waypoints.isNotEmpty) {
            initialCenter = _waypoints.first;
          }

          return Stack(
            children: [
              // ── Flutter Map ──────────────────────────────────────────
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: _activeMode == MapMode.explorer ? 4.0 : 14.0,
                  onTap: (tapPosition, point) {
                    if (state.isAnimating && _activeMode != MapMode.socket) return;

                    if (_activeMode == MapMode.tracking || _activeMode == MapMode.socket) {
                      setState(() {
                        _waypoints.add(point);
                        _routePoints = [];
                      });
                    } else if (_activeMode == MapMode.rideHailing) {
                      setState(() {
                        if (_driverPoint == null) {
                          _driverPoint = point;
                        } else if (_customerPoint == null) {
                          _customerPoint = point;
                        } else if (_destinationPointRide == null) {
                          _destinationPointRide = point;
                        } else {
                          _driverPoint = point;
                          _customerPoint = null;
                          _destinationPointRide = null;
                          _pickupRoutePoints = [];
                          _tripRoutePoints = [];
                          _ridePhase = 'idle';
                        }
                      });
                    }
                  },
                ),
                children: [
                  // CartoDB Voyager Tile Layer
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.osm_location_picker.app',
                  ),

                  // Country Explorer Polygons
                  if (_activeMode == MapMode.explorer && _countryPolygons.isNotEmpty)
                    PolygonLayer(
                      polygons: _countryPolygons,
                    ),

                  // Route Polylines (Car Routing Mode)
                  if (_activeMode == MapMode.tracking)
                    PolylineLayer(
                      polylines: [
                        if (_routePoints.isNotEmpty)
                          Polyline(
                            points: _routePoints,
                            color: Colors.grey.withValues(alpha: 0.5),
                            strokeWidth: 4.5,
                            pattern: const StrokePattern.dotted(),
                          ),
                        if (state.passedPoints.length > 1)
                          Polyline(
                            points: state.passedPoints,
                            color: const Color(0xFF185FA5),
                            strokeWidth: 4.5,
                            strokeCap: StrokeCap.round,
                          ),
                      ],
                    ),

                  // Route Polylines (Ride Hailing Mode)
                  if (_activeMode == MapMode.rideHailing)
                    PolylineLayer(
                      polylines: [
                        // Pickup route (dashed/dotted orange)
                        if (_pickupRoutePoints.isNotEmpty)
                          Polyline(
                            points: _pickupRoutePoints,
                            color: Colors.orange.withValues(alpha: 0.6),
                            strokeWidth: 4.5,
                            pattern: StrokePattern.dashed(segments: const [6, 4]),
                          ),
                        // Trip route (dashed/dotted blue)
                        if (_tripRoutePoints.isNotEmpty)
                          Polyline(
                            points: _tripRoutePoints,
                            color: const Color(0xFF185FA5).withValues(alpha: 0.6),
                            strokeWidth: 4.5,
                            pattern: const StrokePattern.dotted(),
                          ),
                        // Passed pickup/trip points
                        if (state.passedPoints.length > 1)
                          Polyline(
                            points: state.passedPoints,
                            color: _ridePhase == 'pickup' ? Colors.green : const Color(0xFF185FA5),
                            strokeWidth: 5.0,
                            strokeCap: StrokeCap.round,
                          ),
                      ],
                    ),

                  // Route Polylines (Socket Mode)
                  if (_activeMode == MapMode.socket)
                    PolylineLayer(
                      polylines: [
                        if (state.passedPoints.length > 1)
                          Polyline(
                            points: state.passedPoints,
                            color: Colors.blueAccent,
                            strokeWidth: 4.5,
                            strokeCap: StrokeCap.round,
                          ),
                      ],
                    ),

                  // Markers Layer
                  MarkerLayer(
                    markers: [
                      // Car Routing Mode Markers (A, B, C...)
                      if (_activeMode == MapMode.tracking) ...[
                        ..._waypoints.asMap().entries.map((entry) {
                          final index = entry.key;
                          final point = entry.value;
                          final isStart = index == 0;
                          final isEnd = index == _waypoints.length - 1;
                          final label = String.fromCharCode(65 + index); // A, B, C...
                          
                          return Marker(
                            point: point,
                            width: 36.0,
                            height: 36.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isStart 
                                    ? Colors.green 
                                    : (isEnd ? Colors.red : Colors.orange),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],

                      // Ride Hailing Mode Markers (Driver, Customer, Destination)
                      if (_activeMode == MapMode.rideHailing) ...[
                        // Driver Start Location
                        if (_driverPoint != null)
                          Marker(
                            point: _driverPoint!,
                            width: 40.0,
                            height: 40.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blueGrey,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.0),
                              ),
                              child: const Icon(Icons.directions_car, color: Colors.white, size: 20),
                            ),
                          ),
                        // Customer Pickup Location
                        if (_customerPoint != null)
                          Marker(
                            point: _customerPoint!,
                            width: 40.0,
                            height: 40.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.0),
                              ),
                              child: const Icon(Icons.person_pin, color: Colors.white, size: 22),
                            ),
                          ),
                        // Trip Destination Location
                        if (_destinationPointRide != null)
                          Marker(
                            point: _destinationPointRide!,
                            width: 40.0,
                            height: 40.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.0),
                              ),
                              child: const Icon(Icons.flag, color: Colors.white, size: 20),
                            ),
                          ),
                      ],

                      // Animated Car Marker
                      if (state.currentPosition.latitude != 0 && state.isAnimating)
                        Marker(
                          point: state.currentPosition,
                          width: 44.0,
                          height: 44.0,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: state.bearing),
                            duration: const Duration(milliseconds: 300),
                            builder: (_, angle, child) => Transform.rotate(
                              angle: angle,
                              child: child,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _ridePhase == 'pickup' ? Colors.green : const Color(0xFF185FA5),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                              ),
                              child: const Icon(
                                Icons.directions_car,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // ── Top Bar: Mode Switcher & Search Bar ─────────────────
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    // Mode Switcher Tabs (4 Tabs)
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          // Tab 1: Car Routing
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _activeMode == MapMode.tracking ? null : _resetAllStates(MapMode.tracking),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _activeMode == MapMode.tracking
                                      ? const Color(0xFF185FA5)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Center(
                                  child: Text(
                                    'Routing',
                                    style: TextStyle(
                                      color: _activeMode == MapMode.tracking ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Tab 2: Ride Hailing
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _activeMode == MapMode.rideHailing ? null : _resetAllStates(MapMode.rideHailing),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _activeMode == MapMode.rideHailing
                                      ? const Color(0xFF185FA5)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Center(
                                  child: Text(
                                    'Ride-Hailing',
                                    style: TextStyle(
                                      color: _activeMode == MapMode.rideHailing ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Tab 3: Explorer
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _activeMode == MapMode.explorer ? null : _resetAllStates(MapMode.explorer),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _activeMode == MapMode.explorer
                                      ? const Color(0xFF185FA5)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Center(
                                  child: Text(
                                    'Explorer',
                                    style: TextStyle(
                                      color: _activeMode == MapMode.explorer ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Tab 4: Live Socket
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _activeMode == MapMode.socket ? null : _resetAllStates(MapMode.socket),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _activeMode == MapMode.socket
                                      ? const Color(0xFF185FA5)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Center(
                                  child: Text(
                                    'Live Socket',
                                    style: TextStyle(
                                      color: _activeMode == MapMode.socket ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Socket URL Configuration Bar (Visible in socket mode only)
                    if (_activeMode == MapMode.socket)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.link,
                              color: _socketConnectionState == SocketConnectionState.connected
                                  ? Colors.green
                                  : (_socketConnectionState == SocketConnectionState.connecting
                                      ? Colors.orange
                                      : Colors.black54),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _socketUrlController,
                                decoration: const InputDecoration(
                                  hintText: 'ws://ip:port or mock://realtime',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                style: const TextStyle(fontSize: 13),
                                enabled: _socketConnectionState == SocketConnectionState.disconnected,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_socketConnectionState == SocketConnectionState.disconnected)
                              TextButton(
                                onPressed: _connectSocket,
                                child: const Text(
                                  'Connect',
                                  style: TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.bold),
                                ),
                              )
                            else
                              TextButton(
                                onPressed: _disconnectSocket,
                                child: const Text(
                                  'Disconnect',
                                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),

                    // Country Search Bar (Visible in explorer mode only)
                    if (_activeMode == MapMode.explorer)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.black54),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter country (e.g. Egypt, France)',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                onSubmitted: (val) => _searchCountryPolygon(val),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, color: Colors.black54),
                                onPressed: _clearCountryState,
                              ),
                            IconButton(
                              icon: _isSearchingCountry
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.arrow_forward, color: Color(0xFF185FA5)),
                              onPressed: () => _searchCountryPolygon(_searchController.text),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ── Finished Banner (Routing Mode) ──────────────────────
              if (_activeMode == MapMode.tracking && state.isFinished)
                Positioned(
                  bottom: 120,
                  left: 20,
                  right: 20,
                  child: Card(
                    color: const Color(0xFF1D9E75),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 14.0,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strings.arrivedDestination,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Bottom Controls & Info Panels ───────────────────────
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Car Routing Mode Controls ---
                    if (_activeMode == MapMode.tracking)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            if (_waypoints.isEmpty)
                              const Row(
                                children: [
                                  Icon(Icons.touch_app, color: Colors.black54),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Tap on the map to set Start Point (A)',
                                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              )
                            else if (_waypoints.length == 1)
                              const Row(
                                children: [
                                  Icon(Icons.touch_app, color: Colors.green),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Tap on the map to set Destination Point (B)',
                                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.route_outlined, color: Colors.blue, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Route has ${_waypoints.length} waypoints: ${_waypoints.asMap().entries.map((e) => String.fromCharCode(65 + e.key)).join(' → ')}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: _isFetchingRoute
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Icons.navigation),
                                          label: Text(_isFetchingRoute ? 'Fetching Route...' : 'Start Route Tracking'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF185FA5),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: (_isFetchingRoute || state.isAnimating)
                                              ? null
                                              : _fetchAndStartRoute,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE24B4A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: _resetAllStates,
                                        child: const Icon(Icons.refresh),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                    // --- Ride Hailing Mode Controls ---
                    if (_activeMode == MapMode.rideHailing)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            if (_driverPoint == null)
                              const Row(
                                children: [
                                  Icon(Icons.directions_car, color: Colors.blueGrey),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Tap map to set Driver Position (D)',
                                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              )
                            else if (_customerPoint == null)
                              const Row(
                                children: [
                                  Icon(Icons.person_pin, color: Colors.green),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Tap map to set Customer Position (C)',
                                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              )
                            else if (_destinationPointRide == null)
                              const Row(
                                children: [
                                  Icon(Icons.flag, color: Colors.redAccent),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Tap map to set Trip Destination (T)',
                                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.directions_car, color: Colors.blueGrey, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Driver D: ${_driverPoint!.latitude.toStringAsFixed(4)}, ${_driverPoint!.longitude.toStringAsFixed(4)}',
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_pin, color: Colors.green, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Customer C: ${_customerPoint!.latitude.toStringAsFixed(4)}, ${_customerPoint!.longitude.toStringAsFixed(4)}',
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.flag, color: Colors.redAccent, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Destination T: ${_destinationPointRide!.latitude.toStringAsFixed(4)}, ${_destinationPointRide!.longitude.toStringAsFixed(4)}',
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  if (_pickupRoutePoints.isEmpty)
                                    ElevatedButton.icon(
                                      icon: _isFetchingRideRoute
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.calculate),
                                      label: const Text('Calculate Ride Routes'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF185FA5),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 44),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: _isFetchingRideRoute ? null : _fetchRideRoutes,
                                    )
                                  else if (_ridePhase == 'idle' || _ridePhase == 'finished')
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.play_arrow),
                                            label: const Text('Start Ride Hailing'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: _startRideSimulation,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFE24B4A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: _resetAllStates,
                                          child: const Icon(Icons.refresh),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF185FA5)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _ridePhase == 'pickup'
                                                ? 'Status: Driver driving to Customer (Pick-up)'
                                                : 'Status: Trip to Destination in progress...',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF185FA5)),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),

                    // --- Country Details Explorer Panel ---
                    if (_activeMode == MapMode.explorer && _countryDetails != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, color: Color(0xFF185FA5)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _countryDetails!['name'] ?? 'Country Boundary Details',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: _clearCountryState,
                                ),
                              ],
                            ),
                            const Divider(),
                            Text(
                              _countryExplanation,
                              style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),

                    // --- Live Socket Mode Controls ---
                    if (_activeMode == MapMode.socket)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header + Status Indicator
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    _buildStatusDot(),
                                    const SizedBox(width: 8),
                                    Text(
                                      _socketConnectionState == SocketConnectionState.connected
                                          ? 'Connected (Live Data)'
                                          : (_socketConnectionState == SocketConnectionState.connecting
                                              ? 'Connecting...'
                                              : 'Disconnected'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _socketConnectionState == SocketConnectionState.connected
                                            ? Colors.green
                                            : (_socketConnectionState == SocketConnectionState.connecting
                                                ? Colors.orange
                                                : Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Rx Packets: $_socketPacketCount',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            // Telemetry Stats
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildTelemetryItem(
                                  icon: Icons.speed,
                                  label: 'Speed',
                                  value: '${_socketSpeed.toStringAsFixed(1)} km/h',
                                  color: Colors.blueAccent,
                                ),
                                _buildTelemetryItem(
                                  icon: Icons.battery_charging_full,
                                  label: 'Vehicle Battery',
                                  value: '$_socketBattery%',
                                  color: Colors.green,
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            
                            // Instructions / Simulator Trigger
                            if (_waypoints.isEmpty)
                              const Row(
                                children: [
                                  Icon(Icons.touch_app, color: Colors.black54, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Tap map to set path points to stream simulated coordinates.',
                                      style: TextStyle(fontSize: 12, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.route_outlined, color: Colors.blueAccent, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Path has ${_waypoints.length} points defined.',
                                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: _isSocketSimulatorStarting
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                )
                                              : const Icon(Icons.settings_input_component, size: 18),
                                          label: const Text('Stream Simulated GPS', style: TextStyle(fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF185FA5),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: _isSocketSimulatorStarting ? null : _startSocketMockSimulation,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE24B4A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () {
                                          _resetAllStates(MapMode.socket);
                                        },
                                        child: const Icon(Icons.refresh, size: 18),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ── Live Socket Terminal logs Console overlay ────────────
              if (_activeMode == MapMode.socket && _socketLogs.isNotEmpty)
                Positioned(
                  bottom: 270,
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 120,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.terminal, color: Colors.greenAccent, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'WebSocket Incoming Messages Stream',
                                  style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _socketLogs.clear();
                                });
                              },
                              child: const Icon(Icons.delete_outline, color: Colors.grey, size: 16),
                            )
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 10),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _socketLogs.length,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Text(
                                  _socketLogs[index],
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusDot() {
    Color color = Colors.grey;
    if (_socketConnectionState == SocketConnectionState.connected) {
      color = Colors.green;
    } else if (_socketConnectionState == SocketConnectionState.connecting) {
      color = Colors.orange;
    }

    if (_socketConnectionState == SocketConnectionState.connecting ||
        _socketConnectionState == SocketConnectionState.connected) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.3, end: 1.0),
        duration: const Duration(seconds: 1),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  )
                ],
              ),
            ),
          );
        },
      );
    }

    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildTelemetryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }
}
