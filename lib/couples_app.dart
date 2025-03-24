import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:couples_app/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

// import 'dart:html' as html;
import 'package:web_socket_channel/web_socket_channel.dart';

class CouplesApp extends StatefulWidget {
  const CouplesApp({Key? key}) : super(key: key);

  @override
  _CouplesAppState createState() => _CouplesAppState();
}

class _CouplesAppState extends State<CouplesApp> with TickerProviderStateMixin {
  String roomId = "1234";
  final String userId = "user_${Random().nextInt(10000)}";
  bool joined = false;
  String? partnerId;
  Position myPosition = Position(x: 50, y: 50);
  Position partnerPosition = Position(x: 200, y: 200);
  bool isKissing = false;
  String? error;
  WebSocketChannel? _channel;
  late AnimationController _pulseController;
  late AnimationController _heartController;
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    playMusic();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _pulseController.dispose();
    _heartController.dispose();
    _player.dispose();
    super.dispose();
  }

  void playMusic() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    // await _player.play(AssetSource('assets/audio/cute_bgm.mp3'));

    await _player.play(AssetSource('cute_bgm.mp3'));
  }

  void vibrate() {
  
      // Mobile vibration using the vibration package
      Vibration.hasVibrator().then((hasVibrator) {
        if (hasVibrator ?? false) {
          Vibration.vibrate(duration: 200);
        }
      });
    
  }
  void joinRoom() {
    if (roomId.trim().isEmpty) {
      setState(() {
        error = "Please enter a room ID";
      });
      return;
    }

    setState(() {
      error = null;
      joined = true;
    });

    // Connect to WebSocket
    _connectWebSocket();
  }

  void _connectWebSocket() {
    final uri = Uri.parse(
        'wss://s14338.blr1.piesocket.com/v3/$roomId?api_key=RLSuIl2MOvV2e3ipQPWmMl477HknOE8xkkUOxYo4&notify_self=1');

    _channel = WebSocketChannel.connect(uri);

    // Announce joining the room
    Future.delayed(const Duration(milliseconds: 500), () {
      final joinMessage = Message(
        type: "join",
        userId: userId,
        roomId: roomId,
        position: myPosition,
      );
      _channel?.sink.add(jsonEncode(joinMessage.toJson()));
    });

    // Listen for messages
    _channel?.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          final receivedMessage = Message.fromJson(data);

          if (receivedMessage.type == "join" &&
              receivedMessage.userId != userId) {
            setState(() {
              partnerId = receivedMessage.userId;
              if (receivedMessage.position != null) {
                partnerPosition = receivedMessage.position!;
              }
            });

            // Send your position to the new partner
            final positionMessage = Message(
              type: "position",
              userId: userId,
              position: myPosition,
            );
            _channel?.sink.add(jsonEncode(positionMessage.toJson()));
          } else if (receivedMessage.type == "position" &&
              receivedMessage.userId != userId &&
              receivedMessage.position != null) {
            setState(() {
              partnerPosition = receivedMessage.position!;
              partnerId = receivedMessage.userId;
              _checkCollision();
            });
          }
        } catch (e) {
          print("Error parsing message: $e");
        }
      },
      onError: (error) {
        print("WebSocket Error: $error");
        setState(() {
          this.error = "Connection error. Please try again.";
          joined = false;
        });
      },
      onDone: () {
        print("WebSocket connection closed");
      },
    );
  }

  void _checkCollision() {
    final distance = sqrt(pow(myPosition.x - partnerPosition.x, 2) +
        pow(myPosition.y - partnerPosition.y, 2));

    if (distance < 50 && !isKissing) {
      vibrate();
    }

    setState(() {
      isKissing = distance < 50;
    });
  }

  void moveCharacter(double dx, double dy) {
    // Get the size of the game area
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Set game bounds with margin for character size
    const characterSize = 50.0;
    final maxWidth = 300.0; // Fixed game width
    final maxHeight = 300.0; // Fixed game height

    // Calculate new position but keep within bounds
    final newX = max(characterSize / 2,
        min(maxWidth - characterSize / 2, myPosition.x + dx));
    final newY = max(characterSize / 2,
        min(maxHeight - characterSize / 2, myPosition.y + dy));

    setState(() {
      myPosition = Position(x: newX, y: newY);
      _checkCollision();
    });

    // Send position update to partner
    final message = Message(
      type: "position",
      userId: userId,
      position: myPosition,
    );
    _channel?.sink.add(jsonEncode(message.toJson()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFCE4EC), Color(0xFFE1BEE7)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: Colors.pink,
                        size: 30,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Couples Connection',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.favorite,
                        color: Colors.pink,
                        size: 30,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  if (!joined) ...[
                    _buildJoinForm(),
                  ] else ...[
                    _buildGameArea(),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinForm() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: min(MediaQuery.of(context).size.width * 0.9, 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.pink[200]!,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Join Your Sweetie',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.pink[500],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter a secret room ID to connect with your partner',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            initialValue: roomId,
            onChanged: (value) {
              setState(() {
                roomId = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Enter Room ID',
              hintStyle: TextStyle(color: Colors.pink[200]),
              filled: true,
              fillColor: Colors.pink[50],
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 24,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(
                  color: Colors.pink[300]!,
                  width: 2,
                ),
              ),
              prefixIcon: Icon(
                Icons.lock_outlined,
                color: Colors.pink[400],
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: joinRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[500],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
                shadowColor: Colors.pink[200],
              ),
              child: const Text(
                'Connect with Love',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.2),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Room: $roomId',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.pink[600],
                ),
              ),
              const SizedBox(width: 8),
              const Text('•'),
              const SizedBox(width: 8),
              partnerId != null
                  ? Row(
                      children: [
                        Text(
                          'Partner connected!',
                          style: TextStyle(
                            color: Colors.pink[600],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('💕'),
                      ],
                    )
                  : Row(
                      children: [
                        Text(
                          'Waiting for partner...',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('💌'),
                      ],
                    ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

            return isWide
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildGameBoard(),
                      const SizedBox(width: 20),
                      _buildControls(),
                    ],
                  )
                : Column(
                    children: [
                      _buildGameBoard(),
                      const SizedBox(height: 20),
                      _buildControls(),
                    ],
                  );
          },
        ),
      ],
    );
  }

  Widget _buildGameBoard() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.pink[300]!,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Floating background hearts
            ...List.generate(5, (index) {
              final random = Random();
              return Positioned(
                left: random.nextDouble() * 250,
                top: random.nextDouble() * 250,
                child: AnimatedBuilder(
                  animation: _heartController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        0,
                        -20 * sin((_heartController.value * 2 * pi) + index),
                      ),
                      child: Opacity(
                        opacity: 0.3,
                        child: Icon(
                          Icons.favorite,
                          color: Colors.pink[300],
                          size: 20 + (10 * random.nextDouble()),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),

            // Your character
            Positioned(
              left: myPosition.x - 25,
              top: myPosition.y - 25,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale:
                        isKissing ? 1.0 + (_pulseController.value * 0.2) : 1.0,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.pink[300]!,
                            Colors.pink[600]!,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isKissing
                                ? Colors.pink.withOpacity(0.7)
                                : Colors.black.withOpacity(0.2),
                            blurRadius: isKissing ? 15 : 5,
                            spreadRadius: isKissing ? 5 : 0,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '👩',
                          style: TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Partner character
            if (partnerId != null)
              Positioned(
                left: partnerPosition.x - 25,
                top: partnerPosition.y - 25,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isKissing
                          ? 1.0 + (_pulseController.value * 0.2)
                          : 1.0,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue[300]!,
                              Colors.blue[600]!,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isKissing
                                  ? Colors.blue.withOpacity(0.7)
                                  : Colors.black.withOpacity(0.2),
                              blurRadius: isKissing ? 15 : 5,
                              spreadRadius: isKissing ? 5 : 0,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '👨',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Kiss effect
            if (isKissing)
              Positioned(
                left: (myPosition.x + partnerPosition.x) / 2 - 20,
                top: (myPosition.y + partnerPosition.y) / 2 - 20,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.5),
                      child: const Opacity(
                        opacity: 0.8,
                        child: Text(
                          '💋',
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: ElevatedButton(
              onPressed: () => moveCharacter(0, -30),
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(0),
                backgroundColor: Colors.pink[500],
                foregroundColor: Colors.white,
                elevation: 5,
                shadowColor: Colors.pink[200],
              ),
              child: const Icon(
                Icons.arrow_upward,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => moveCharacter(-30, 0),
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(0),
                    backgroundColor: Colors.pink[500],
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shadowColor: Colors.pink[200],
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 60,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => moveCharacter(0, 30),
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(0),
                    backgroundColor: Colors.pink[500],
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shadowColor: Colors.pink[200],
                  ),
                  child: const Icon(
                    Icons.arrow_downward,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 60,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => moveCharacter(30, 0),
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(0),
                    backgroundColor: Colors.pink[500],
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shadowColor: Colors.pink[200],
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    size: 30,
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
