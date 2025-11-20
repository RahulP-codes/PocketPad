import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to landscape
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Auto-hide navigation bars after timeout
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
  
  runApp(const PocketPadApp());
}

class PocketPadApp extends StatelessWidget {
  const PocketPadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketPad',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PocketPadHome(),
    );
  }
}

class PocketPadHome extends StatefulWidget {
  const PocketPadHome({super.key});

  @override
  State<PocketPadHome> createState() => _PocketPadHomeState();
}

class _PocketPadHomeState extends State<PocketPadHome> {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isScanning = false;
  String _serverIp = '';
  String _statusMessage = 'Ready to scan';

  
  // For relative movement tracking
  Offset? _lastTouchPosition;
  bool _isDragging = false;
  static const double _movementThreshold = 0.5; // Minimum movement to register
  
  // For two-finger gestures
  final Map<int, Offset> _activePointers = {};
  Offset? _lastTwoFingerCenter;
  bool _sessionLogged = false; // Track if session already logged
  double _zoomLevel = 1.0; // Zoom level control
  bool _isTwoFingerMode = false; // Track if in 2-finger mode
  Timer? _clickDelayTimer; // Delay timer for click detection

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 500), () {
      _scanForServer();
    });

    _startConnectionMonitoring();

    _startAutoHideTimer();
  }

  void _startAutoHideTimer() {

    Timer.periodic(Duration(seconds: 3), (timer) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
    });
  }



  void _startConnectionMonitoring() {

    Timer.periodic(Duration(seconds: 3), (timer) {
      if (!_isConnected && !_isScanning && _serverIp.isNotEmpty) {

        _reconnectToKnownServer();
      }
    });
    

    Timer.periodic(Duration(seconds: 10), (timer) {
      if (_isConnected && _channel != null) {
        try {

          final healthCheck = json.encode({'type': 'health_check'});
          _channel!.sink.add(healthCheck);
        } catch (e) {

          setState(() {
            _isConnected = false;
            _statusMessage = 'Health check failed - reconnecting...';
          });
          _reconnectToKnownServer();
        }
      }
    });
  }


  List<String> _getIPsToScan() {
    return [
      '10.130.84.77',
      '10.248.231.157', '192.168.0.103',
      '10.21.109.77', '10.140.84.21',
      '192.168.1.100', '192.168.1.101', '192.168.1.102', '192.168.1.1',
      '192.168.0.100', '192.168.0.101', '192.168.0.102', '192.168.0.1',
      '10.0.0.100', '10.0.0.101', '10.0.0.1',
      '172.16.0.100', '172.16.0.1',
    ];
  }

  Future<void> _scanForServer() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Listening for server broadcast...';
    });

    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8766);
      socket.broadcastEnabled = true;
      
      final timeout = Timer(Duration(seconds: 5), () {
        socket.close();
      });
      
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final packet = socket.receive();
          if (packet != null) {
            final message = String.fromCharCodes(packet.data);
            if (message.startsWith('POCKETPAD_SERVER:')) {
              final serverIp = packet.address.address;
              timeout.cancel();
              socket.close();
              _connectToDiscoveredServer(serverIp);
            }
          }
        }
      });
      
      await Future.delayed(Duration(seconds: 5));
      if (_isScanning) {
        setState(() {
          _statusMessage = 'No broadcast found, trying manual scan...';
        });
        _manualScan();
      }
    } catch (e) {
      _manualScan();
    }
  }
  
  Future<void> _manualScan() async {
    final ipsToScan = _getIPsToScan();
    
    for (String ip in ipsToScan) {
      if (!_isScanning) break;
      
      setState(() {
        _statusMessage = 'Trying $ip...';
      });

      try {

        final channel = WebSocketChannel.connect(
          Uri.parse('ws://$ip:8765'),
        );
        

        final testMessage = json.encode({'type': 'connection_test'});
        channel.sink.add(testMessage);
        

        final response = await Future.any([
          channel.stream.first.timeout(Duration(seconds: 3)),
          Future.delayed(Duration(seconds: 3)).then((_) => throw TimeoutException('Connection timeout', Duration(seconds: 3))),
        ]);
        

        if (response != null) {
          setState(() {
            _serverIp = ip;
            _channel = channel;
            _isConnected = true;
            _isScanning = false;
            _statusMessage = 'Connected to $ip';
          });
          
          _setupChannelListeners();
          return;
        }
        
      } catch (e) {

        continue;
      }
    }
    

    setState(() {
      _isScanning = false;
      _statusMessage = 'No PocketPad server found. Make sure server is running.';
    });
  }
  
  Future<void> _connectToDiscoveredServer(String ip) async {
    setState(() {
      _statusMessage = 'Found server at $ip, connecting...';
    });
    
    try {
      final channel = WebSocketChannel.connect(Uri.parse('ws://$ip:8765'));
      final testMessage = json.encode({'type': 'connection_test'});
      channel.sink.add(testMessage);
      await channel.stream.first.timeout(Duration(seconds: 3));
      
      setState(() {
        _serverIp = ip;
        _channel = channel;
        _isConnected = true;
        _isScanning = false;
        _statusMessage = 'Connected to $ip';
      });
      
      _setupChannelListeners();
    } catch (e) {
      _manualScan();
    }
  }

  void _setupChannelListeners() {
    _channel?.stream.listen(
      (message) {},
      onError: (error) {
        setState(() {
          _isConnected = false;
          _statusMessage = 'Connection lost - will auto-reconnect';
        });
        Future.delayed(Duration(seconds: 2), () {
          if (!_isConnected && !_isScanning) {
            _reconnectToKnownServer();
          }
        });
      },
      onDone: () {
        setState(() {
          _isConnected = false;
          _statusMessage = 'Disconnected - will auto-reconnect';
        });
        Future.delayed(Duration(seconds: 2), () {
          if (!_isConnected && !_isScanning) {
            _reconnectToKnownServer();
          }
        });
      },
    );
    
    _startSimpleKeepAlive();
  }

  void _startSimpleKeepAlive() {
    Timer.periodic(Duration(seconds: 10), (timer) {
      if (_isConnected && _channel != null) {
        try {
          final keepalive = json.encode({'type': 'keepalive'});
          _channel!.sink.add(keepalive);
        } catch (e) {
          timer.cancel();
          setState(() {
            _isConnected = false;
            _statusMessage = 'Keepalive failed - reconnecting...';
          });
          _reconnectToKnownServer();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _connectToServer() {
    if (_serverIp.isEmpty) {
      _scanForServer();
    } else {
      _reconnectToKnownServer();
    }
  }

  Future<void> _reconnectToKnownServer() async {
    if (_serverIp.isEmpty) {
      _scanForServer();
      return;
    }

    setState(() {
      _statusMessage = 'Reconnecting to $_serverIp...';
    });

    try {
      _channel?.sink.close();
      
      final channel = WebSocketChannel.connect(
        Uri.parse('ws://$_serverIp:8765'),
      );
      

      final testMessage = json.encode({'type': 'connection_test'});
      channel.sink.add(testMessage);
      

      await channel.stream.first.timeout(Duration(seconds: 3));
      

      setState(() {
        _channel = channel;
        _isConnected = true;
        _statusMessage = 'Reconnected to $_serverIp';
      });
      
      _setupChannelListeners();
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = 'Reconnection failed - scanning for server...';
      });

      Future.delayed(Duration(seconds: 2), () {
        _scanForServer();
      });
    }
  }

  void _sendTouchEvent(double x, double y, String type) {
    if (_channel != null && _isConnected) {
      try {
        final message = json.encode({
          'type': type,
          'x': x.round(),
          'y': y.round(),
        });
        _channel!.sink.add(message);
      } catch (e) {
        setState(() {
          _isConnected = false;
          _statusMessage = 'Send failed - reconnecting...';
        });
        _reconnectToKnownServer();
      }
    } else if (!_isConnected && !_isScanning) {
      _reconnectToKnownServer();
    }
  }
  
  void _sendHoverMovement(double deltaX, double deltaY) {
    if (_channel != null && _isConnected) {
      try {
        final message = json.encode({
          'type': 'hover_move',
          'deltaX': deltaX.round(),
          'deltaY': deltaY.round(),
        });
        _channel!.sink.add(message);
      } catch (e) {
        setState(() {
          _isConnected = false;
          _statusMessage = 'Send failed - reconnecting...';
        });
        _reconnectToKnownServer();
      }
    }
  }
  
  void _sendRelativeMovement(double deltaX, double deltaY) {
    if (_channel != null && _isConnected) {
      try {
        final message = json.encode({
          'type': 'move_relative',
          'deltaX': deltaX.round(),
          'deltaY': deltaY.round(),
        });
        _channel!.sink.add(message);
      } catch (e) {
        setState(() {
          _isConnected = false;
          _statusMessage = 'Send failed - reconnecting...';
        });
        _reconnectToKnownServer();
      }
    }
  }
  
  void _sendZoomLevel(double level) {
    if (_channel != null && _isConnected) {
      try {
        final message = json.encode({
          'type': 'zoom_level',
          'level': level,
        });
        _channel!.sink.add(message);
      } catch (e) {}
    }
  }
  
  double _calculateDistance(Offset point1, Offset point2) {
    final dx = point1.dx - point2.dx;
    final dy = point1.dy - point2.dy;
    return sqrt(dx * dx + dy * dy);
  }

  @override
  void dispose() {
    _clickDelayTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green : (_isScanning ? Colors.orange : Colors.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🖱️ PocketPad',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isConnected 
                      ? '✅ Connected to $_serverIp:8765'
                      : (_isScanning ? '🔍 $_statusMessage' : '❌ $_statusMessage'),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            
            // Connect/Scan Button
            if (!_isConnected && !_isScanning)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _connectToServer,
                      child: Text(_serverIp.isEmpty ? 'Scan for Server' : 'Reconnect'),
                    ),
                    if (_serverIp.isNotEmpty)
                      const SizedBox(height: 10),
                    if (_serverIp.isNotEmpty)
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _serverIp = '');
                          _scanForServer();
                        },
                        child: const Text('Scan Again'),
                      ),
                  ],
                ),
              ),
            
            // Stop Scanning Button
            if (_isScanning)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => setState(() => _isScanning = false),
                  child: const Text('Stop Scanning'),
                ),
              ),
            
            // Zoom Control Slider
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Zoom Level: ${_zoomLevel.toStringAsFixed(1)}x'),
                  Slider(
                    value: _zoomLevel,
                    min: 0.5,
                    max: 3.0,
                    divisions: 10,
                    onChanged: (value) {
                      setState(() {
                        _zoomLevel = value;
                      });
                      _sendZoomLevel(value);
                    },
                  ),
                ],
              ),
            ),
            

        ],
      ),
      ),
      body: Stack(
        children: [
          // Menu Button
          Positioned(
            top: 10,
            left: 10,
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.menu, color: Colors.white54, size: 20),
                ),
              ),
            ),
          ),
          
          // Main Content
          Column(
            children: [
              
              // Touch Area - Fixed for all positions
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 60),
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (PointerDownEvent event) {
                      _activePointers[event.pointer] = event.localPosition;
                      
                      if (_activePointers.length == 1 && !_isTwoFingerMode) {
                        _lastTouchPosition = event.localPosition;
                        _clickDelayTimer?.cancel();
                        
                        _clickDelayTimer = Timer(Duration(milliseconds: 100), () {
                          if (_activePointers.length == 1 && !_isTwoFingerMode) {
                            _isDragging = true;
                            _sendTouchEvent(0, 0, 'down');
                          }
                        });
                      } else if (_activePointers.length == 2) {
                        _clickDelayTimer?.cancel();
                        _isTwoFingerMode = true;
                        
                        if (_isDragging) {
                          _sendTouchEvent(0, 0, 'up');
                          _isDragging = false;
                        }
                        
                        final positions = _activePointers.values.toList();
                        _lastTwoFingerCenter = Offset(
                          (positions[0].dx + positions[1].dx) / 2,
                          (positions[0].dy + positions[1].dy) / 2,
                        );
                      } else {
                        _activePointers.remove(event.pointer);
                      }
                      
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
                    },
                    onPointerMove: (PointerMoveEvent event) {
                      _activePointers[event.pointer] = event.localPosition;
                      
                      if (_activePointers.length == 1 && _isDragging) {
                        // Single finger movement
                        if (_lastTouchPosition == null) return;
                        
                        final currentPosition = event.localPosition;
                        final deltaX = (currentPosition.dx - _lastTouchPosition!.dx) * 1.5;
                        final deltaY = (currentPosition.dy - _lastTouchPosition!.dy) * 1.5;
                        
                        final distance = (deltaX * deltaX + deltaY * deltaY);
                        if (distance > _movementThreshold * _movementThreshold) {
                          _sendRelativeMovement(deltaX, deltaY);
                          _lastTouchPosition = currentPosition;
                          if (!_sessionLogged) {
                            _sessionLogged = true;
                          }
                        }
                      } else if (_activePointers.length == 2) {
                        // 2-finger hover mode - NO CLICKS, only movement
                        final positions = _activePointers.values.toList();
                        final currentCenter = Offset(
                          (positions[0].dx + positions[1].dx) / 2,
                          (positions[0].dy + positions[1].dy) / 2,
                        );
                        
                        // Two-finger hover movement (no clicks)
                        if (_lastTwoFingerCenter != null) {
                          final deltaX = (currentCenter.dx - _lastTwoFingerCenter!.dx) * 1.5;
                          final deltaY = (currentCenter.dy - _lastTwoFingerCenter!.dy) * 1.5;
                          
                          final distance = (deltaX * deltaX + deltaY * deltaY);
                          if (distance > _movementThreshold * _movementThreshold) {
                            _sendHoverMovement(deltaX, deltaY);
                            _lastTwoFingerCenter = currentCenter;
                            if (!_sessionLogged) {
                              _sessionLogged = true;
                            }
                          }
                        }
                      }
                    },
                    onPointerUp: (PointerUpEvent event) {
                      _activePointers.remove(event.pointer);
                      
                      if (_activePointers.isEmpty) {
                        // All fingers lifted - reset everything
                        _clickDelayTimer?.cancel(); // Cancel any pending click
                        if (_isDragging) {
                          _sendTouchEvent(0, 0, 'up');
                        }
                        _isDragging = false;
                        _lastTwoFingerCenter = null;
                        _isTwoFingerMode = false;
                        _sessionLogged = false;
                      } else if (_activePointers.length == 1 && _isTwoFingerMode) {
                        // Going from 2-finger back to 1-finger - stay in hover mode
                        _lastTouchPosition = _activePointers.values.first;
                        _lastTwoFingerCenter = null;
                      } else if (_activePointers.length == 1 && !_isTwoFingerMode) {
                        // Continue existing 1-finger session
                        _lastTouchPosition = _activePointers.values.first;
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        border: Border.all(color: Colors.grey[600]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '📱 Touch Area\n\n1 finger: Click + Move (left click ON)\n2 fingers: Hover + Move (no clicking)\n\nCursor continues from last position\n(Tap top-left corner for menu)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey[300]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}