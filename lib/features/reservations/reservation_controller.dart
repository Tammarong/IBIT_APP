import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

class ReservationController extends ChangeNotifier {
  ReservationController(this.repository);
  final ReservationRepository repository;
  String _requestId = const Uuid().v4();
  String? _payload;
  bool busy = false;
  String? error;
  bool _disposed = false;
  bool isRetryOf({
    required String roomId,
    required String date,
    required int startMinute,
    required int endMinute,
    required String purpose,
  }) =>
      error != null &&
      _payload == '$roomId|$date|$startMinute|$endMinute|$purpose';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<Reservation?> reserve({
    required String roomId,
    required String date,
    required int startMinute,
    required int endMinute,
    required String purpose,
  }) async {
    if (busy) return null;
    final payload = '$roomId|$date|$startMinute|$endMinute|$purpose';
    if (_payload != null && _payload != payload) _requestId = const Uuid().v4();
    _payload = payload;
    busy = true;
    error = null;
    _notify();
    try {
      return await repository.createReservation(
        requestId: _requestId,
        roomId: roomId,
        date: date,
        startMinute: startMinute,
        endMinute: endMinute,
        purpose: purpose,
      );
    } on ReservationException catch (e) {
      error = e.message;
      return null;
    } catch (_) {
      error =
          'We couldn’t confirm your reservation. Check your connection and try again.';
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
