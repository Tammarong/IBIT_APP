import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  const Room({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.assetPath,
    this.imageUrl,
    this.facilities = const [],
  });

  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String assetPath;
  final String? imageUrl;
  final List<String> facilities;

  factory Room.fromMap(String id, Map<String, dynamic> data) => Room(
    id: id,
    name: data['name'] as String? ?? 'IBIT Room',
    subtitle: data['subtitle'] as String? ?? 'A space for your next idea',
    description: data['description'] as String? ?? '',
    assetPath: data['assetPath'] as String? ?? 'assets/rooms/$id.png',
    imageUrl: data['imageUrl'] as String?,
    facilities: List<String>.from(data['facilities'] as List? ?? const []),
  );
}

class BusyInterval {
  const BusyInterval({
    required this.reservationId,
    required this.startMinute,
    required this.endMinute,
  });

  final String reservationId;
  final int startMinute;
  final int endMinute;

  factory BusyInterval.fromMap(Map<String, dynamic> data) => BusyInterval(
    reservationId: data['reservationId'] as String,
    startMinute: (data['startMinute'] as num).toInt(),
    endMinute: (data['endMinute'] as num).toInt(),
  );
}

class Reservation {
  const Reservation({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.date,
    required this.startMinute,
    required this.endMinute,
    required this.purpose,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String userId;
  final String date;
  final int startMinute;
  final int endMinute;
  final String purpose;
  final String status;
  final int createdAt;

  bool get isCancelled => status == 'cancelled';
  String get reference =>
      'IBIT-${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}';

  factory Reservation.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['createdAt'];
    return Reservation(
      id: id,
      roomId: data['roomId'] as String,
      userId: data['userId'] as String,
      date: data['date'] as String,
      startMinute: (data['startMinute'] as num).toInt(),
      endMinute: (data['endMinute'] as num).toInt(),
      purpose: data['purpose'] as String,
      status: data['status'] as String,
      createdAt: timestamp is Timestamp
          ? timestamp.millisecondsSinceEpoch
          : (timestamp as num?)?.toInt() ?? 0,
    );
  }
}
