class Position {
  double x;
  double y;

  Position({required this.x, required this.y});

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
      };

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      x: json['x'].toDouble(),
      y: json['y'].toDouble(),
    );
  }
}

class Message {
  final String type;
  final String userId;
  final Position? position;
  final String? roomId;

  Message({
    required this.type,
    required this.userId,
    this.position,
    this.roomId,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'type': type,
      'userId': userId,
    };
    if (position != null) {
      data['position'] = position!.toJson();
    }
    if (roomId != null) {
      data['roomId'] = roomId;
    }
    return data;
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      type: json['type'],
      userId: json['userId'],
      position: json['position'] != null
          ? Position.fromJson(json['position'])
          : null,
      roomId: json['roomId'],
    );
  }
}
