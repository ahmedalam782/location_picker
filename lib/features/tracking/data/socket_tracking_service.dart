import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum SocketConnectionState { disconnected, connecting, connected }

class SocketTrackingService {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _mockTimer;
  int _mockIndex = 0;
  List<LatLng> _mockPoints = [];

  final StreamController<String> _messageController = StreamController<String>.broadcast();
  final StreamController<SocketConnectionState> _stateController =
      StreamController<SocketConnectionState>.broadcast();

  SocketConnectionState _currentState = SocketConnectionState.disconnected;

  Stream<String> get messagesStream => _messageController.stream;
  Stream<SocketConnectionState> get connectionStateStream => _stateController.stream;
  SocketConnectionState get currentState => _currentState;

  void _updateState(SocketConnectionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  /// Connect to the given WebSocket URL.
  /// If the URL starts with "mock://", we will simulate a local WebSocket connection.
  Future<void> connect(String url) async {
    await disconnect();

    _updateState(SocketConnectionState.connecting);

    if (url.startsWith('mock://')) {
      // Simulate connection delay
      await Future.delayed(const Duration(milliseconds: 600));
      _updateState(SocketConnectionState.connected);
      _logMockMessage('System', 'Connected to Mock WebSocket Loopback.');
      return;
    }

    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);
      
      // Listen to the stream
      _channelSubscription = _channel!.stream.listen(
        (message) {
          if (_currentState == SocketConnectionState.connecting) {
            _updateState(SocketConnectionState.connected);
          }
          _messageController.add(message.toString());
        },
        onError: (error) {
          _logMockMessage('Error', 'WebSocket Error: $error');
          disconnect();
        },
        onDone: () {
          _logMockMessage('System', 'WebSocket Connection Closed.');
          disconnect();
        },
      );

      // Transition to connected once listening starts
      _updateState(SocketConnectionState.connected);
    } catch (e) {
      _updateState(SocketConnectionState.disconnected);
      _messageController.add(jsonEncode({
        'type': 'system_error',
        'message': 'Failed to connect: $e',
        'timestamp': DateTime.now().toIso8601String()
      }));
      rethrow;
    }
  }

  /// Disconnect the active WebSocket or stop the simulator.
  Future<void> disconnect() async {
    stopMockSimulation();
    
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    
    await _channel?.sink.close();
    _channel = null;

    if (_currentState != SocketConnectionState.disconnected) {
      _updateState(SocketConnectionState.disconnected);
      _logMockMessage('System', 'Disconnected from WebSocket.');
    }
  }

  /// Start the simulated location broadcasts using a list of LatLng coordinates.
  void startMockSimulation(List<LatLng> points) {
    stopMockSimulation();
    if (points.isEmpty) return;

    _mockPoints = points;
    _mockIndex = 0;

    _mockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_mockPoints.isEmpty) return;
      if (_mockIndex >= _mockPoints.length) {
        // Loop back to start or finish
        _mockIndex = 0;
      }

      final current = _mockPoints[_mockIndex];
      double bearing = 0.0;
      if (_mockIndex < _mockPoints.length - 1) {
        bearing = _calcBearing(current, _mockPoints[_mockIndex + 1]);
      } else if (_mockIndex > 0) {
        bearing = _calcBearing(_mockPoints[_mockIndex - 1], current);
      }

      final speed = 35 + Random().nextInt(25); // Random speed between 35 and 60 km/h

      final jsonPacket = jsonEncode({
        'type': 'location',
        'latitude': current.latitude,
        'longitude': current.longitude,
        'bearing': bearing,
        'speed': speed.toDouble(),
        'timestamp': DateTime.now().toIso8601String(),
        'battery': 98 - (_mockIndex ~/ 2), // Mock draining battery
        'driver_id': 'driver_482'
      });

      _messageController.add(jsonPacket);
      _mockIndex++;
    });
    
    _logMockMessage('System', 'Mock Real-Time simulation stream started.');
  }

  /// Stop the simulated location broadcaster.
  void stopMockSimulation() {
    _mockTimer?.cancel();
    _mockTimer = null;
    _mockPoints = [];
    _mockIndex = 0;
  }

  void _logMockMessage(String type, String text) {
    _messageController.add(jsonEncode({
      'type': 'system_log',
      'log_type': type,
      'message': text,
      'timestamp': DateTime.now().toIso8601String()
    }));
  }

  double _calcBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final dLng = (to.longitude - from.longitude) * pi / 180;
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    return atan2(y, x);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _stateController.close();
  }
}
