import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';

import '../core/firebase_config.dart';
import 'models.dart';

abstract interface class RoomRepository {
  Stream<List<Room>> watchRooms();
  Stream<Map<String, List<BusyInterval>>> watchAvailability(String date);
}

abstract interface class ReservationRepository {
  Stream<List<Reservation>> watchMyReservations(String uid);
  Future<Reservation> createReservation({
    required String requestId,
    required String roomId,
    required String date,
    required int startMinute,
    required int endMinute,
    required String purpose,
  });
  Future<Reservation> cancelReservation(String id);
}

class ReservationException implements Exception {
  const ReservationException(this.message, this.code);
  final String message;
  final String code;
  @override
  String toString() => message;
}

class FirebaseRoomRepository implements RoomRepository {
  FirebaseRoomRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  late final Future<List<Map<String, dynamic>>> _catalog = rootBundle
      .loadString('assets/rooms/itd_catalog.json')
      .then(
        (content) => (jsonDecode(content) as List)
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList(),
      );

  @override
  Stream<List<Room>> watchRooms() async* {
    final catalog = await _catalog;
    yield* _firestore.collection('rooms').snapshots().map((snapshot) {
      final live = {for (final doc in snapshot.docs) doc.id: doc.data()};
      final catalogIds = catalog.map((entry) => entry['id'] as String).toSet();
      final rooms = catalog.map((entry) {
        final id = entry['id'] as String;
        final configured = live[id];
        return Room.fromMap(id, {
          ...entry,
          'subtitle': 'Floor ${entry['floor']} · ITD, KMUTNB',
          'description': '',
          'assetPath': 'assets/rooms/room-01.png',
          ...?configured,
          // A room cannot be reserved until its server-side document exists.
          'bookingEnabled':
              configured != null &&
              entry['bookingEnabled'] == true &&
              configured['bookingEnabled'] == true,
        });
      }).toList();
      rooms.addAll(
        snapshot.docs
            .where((doc) => !catalogIds.contains(doc.id))
            .map(
              (doc) => Room.fromMap(doc.id, {...doc.data(), 'listed': false}),
            ),
      );
      rooms.sort((a, b) => a.name.compareTo(b.name));
      return rooms;
    });
  }

  @override
  Stream<Map<String, List<BusyInterval>>> watchAvailability(String date) =>
      _firestore
          .collection('roomDays')
          .where('date', isEqualTo: date)
          .snapshots()
          .map(
            (snapshot) => {
              for (final doc in snapshot.docs)
                doc.data()['roomId'] as String:
                    (doc.data()['intervals'] as List? ?? [])
                        .map(
                          (value) => BusyInterval.fromMap(
                            Map<String, dynamic>.from(value as Map),
                          ),
                        )
                        .toList()
                      ..sort((a, b) => a.startMinute.compareTo(b.startMinute)),
            },
          );
}

class FirebaseReservationRepository implements ReservationRepository {
  FirebaseReservationRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: EmulatorConfig.region);
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<List<Reservation>> watchMyReservations(String uid) => _firestore
      .collection('reservations')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snapshot) {
        final reservations = snapshot.docs
            .map((doc) => Reservation.fromMap(doc.id, doc.data()))
            .toList();
        reservations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return reservations;
      });

  @override
  Future<Reservation> createReservation({
    required String requestId,
    required String roomId,
    required String date,
    required int startMinute,
    required int endMinute,
    required String purpose,
  }) => _call('createReservation', {
    'requestId': requestId,
    'roomId': roomId,
    'date': date,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'purpose': purpose.trim(),
  });

  @override
  Future<Reservation> cancelReservation(String id) =>
      _call('cancelReservation', {'reservationId': id});

  Future<Reservation> _call(
    String name,
    Map<String, dynamic> parameters,
  ) async {
    try {
      final response = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 25)),
          )
          .call<Map<String, dynamic>>(parameters);
      final reservation = Map<String, dynamic>.from(
        response.data['reservation'] as Map,
      );
      return Reservation.fromMap(reservation['id'] as String, reservation);
    } on FirebaseFunctionsException catch (error) {
      final message = switch (error.code) {
        'unavailable' || 'deadline-exceeded' =>
          'We could not reach IBIT Rooms. Check your connection, then retry. '
              'Your previous request will not create a duplicate booking.',
        'unauthenticated' => 'Please sign in again to continue.',
        'invalid-argument' ||
        'failed-precondition' ||
        'already-exists' ||
        'not-found' ||
        'permission-denied' =>
          error.message ??
              'We could not complete your request. Please try again.',
        _ => 'We could not complete your request. Please retry in a moment.',
      };
      throw ReservationException(message, error.code);
    }
  }
}
