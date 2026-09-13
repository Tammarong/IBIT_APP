import 'package:flutter_test/flutter_test.dart';
import 'package:rooms/core/booking_time.dart';
import 'package:rooms/data/models.dart';

void main() {
  final beforeMonday = DateTime.utc(2026, 9, 13, 18);
  String? validate(
    int start,
    int end, {
    String date = '2026-09-14',
    List<BusyInterval> busy = const [],
  }) => BookingTime.validate(
    date: date,
    startMinute: start,
    endMinute: end,
    busy: busy,
    now: beforeMonday,
  );

  test('Bangkok calendar stays independent of device timezone at midnight', () {
    expect(
      BookingTime.dateKey(BookingTime.today(DateTime.utc(2026, 9, 13, 17))),
      '2026-09-14',
    );
    expect(
      BookingTime.instant('2026-09-14', 480),
      DateTime.utc(2026, 9, 14, 1),
    );
    expect(
      BookingTime.dateKey(
        BookingTime.nextBookableDate(DateTime.utc(2026, 9, 11, 9)),
      ),
      '2026-09-14',
    );
  });

  test('arbitrary minutes and both exact session boundaries are accepted', () {
    expect(validate(480, 720), isNull);
    expect(validate(780, 960), isNull);
    expect(validate(490, 575), isNull);
    expect(validate(959, 960), isNull);
  });

  test(
    'lunch, out of hours, reversed and zero-length requests are rejected',
    () {
      for (final pair in [
        (479, 500),
        (700, 781),
        (720, 780),
        (780, 961),
        (500, 500),
        (500, 490),
      ]) {
        expect(validate(pair.$1, pair.$2), isNotNull, reason: '$pair');
      }
    },
  );

  test('invalid dates and weekends are rejected', () {
    expect(validate(480, 500, date: '2026-09-19'), isNotNull);
    expect(validate(480, 500, date: '2026-09-20'), isNotNull);
    expect(validate(480, 500, date: '2026-02-30'), isNotNull);
    expect(validate(480, 500, date: 'not-a-date'), isNotNull);
  });

  test('an exact current start time is rejected; next minute is allowed', () {
    final at = DateTime.utc(2026, 9, 14, 1, 10);
    expect(
      BookingTime.validate(
        date: '2026-09-14',
        startMinute: 490,
        endMinute: 500,
        now: at,
      ),
      isNotNull,
    );
    expect(
      BookingTime.validate(
        date: '2026-09-14',
        startMinute: 491,
        endMinute: 500,
        now: at,
      ),
      isNull,
    );
  });

  test(
    'adjacent bookings are allowed but containment and overlaps rejected',
    () {
      const busy = [
        BusyInterval(reservationId: 'a', startMinute: 540, endMinute: 600),
      ];
      expect(validate(480, 540, busy: busy), isNull);
      expect(validate(600, 660, busy: busy), isNull);
      for (final pair in [(539, 541), (550, 590), (539, 601), (599, 601)]) {
        expect(
          validate(pair.$1, pair.$2, busy: busy),
          isNotNull,
          reason: '$pair',
        );
      }
      expect(
        validate(540, 600),
        isNull,
        reason: 'A different room has its own busy intervals.',
      );
    },
  );

  test('12-hour formatting handles noon and arbitrary minutes', () {
    expect(BookingTime.formatMinute(490), '8:10 AM');
    expect(BookingTime.formatMinute(720), '12:00 PM');
    expect(BookingTime.formatMinute(780), '1:00 PM');
    expect(BookingTime.durationLabel(85), '1 hr 25 min');
    expect(BookingTime.formatDate('2026-09-14'), 'Mon, 14 September 2026');
  });
}
