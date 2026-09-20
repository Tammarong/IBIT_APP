import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/booking_time.dart';
import '../data/models.dart';

DateTime facultyNow() => BookingTime.now();
String dayKey(DateTime date) => BookingTime.dateKey(date);
DateTime dateOnly(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);
DateTime nextWeekday(DateTime date) {
  var day = dateOnly(date);
  while (day.weekday > 5) {
    day = day.add(const Duration(days: 1));
  }
  return day;
}

DateTime initialBookingDate() => BookingTime.nextBookableDate();

String timeLabel(int minute) => BookingTime.formatMinute(minute);
String dateLabel(String date) =>
    DateFormat('EEE, d MMM yyyy').format(DateTime.parse(date));

Future<DateTime?> pickBookingDate(BuildContext context, DateTime selected) {
  final first = dateOnly(facultyNow());
  final last = DateTime.utc(first.year + 10, 12, 31);
  return showDatePicker(
    context: context,
    initialDate: nextWeekday(selected.isBefore(first) ? first : selected),
    firstDate: first,
    lastDate: last,
    selectableDayPredicate: (d) => d.weekday < 6,
    helpText: 'Choose your room date',
    confirmText: 'Select date',
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = AppColors.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.8,
      color: color,
    ),
  );
}

class RoomArtwork extends StatelessWidget {
  const RoomArtwork({super.key, required this.room, this.height = 210});
  final Room room;
  final double height;
  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
      height: height,
      color: AppColors.mint,
      alignment: Alignment.center,
      child: const Icon(
        Icons.meeting_room_outlined,
        size: 64,
        color: AppColors.accent,
      ),
    );
    Widget bundled() => Image.asset(
      room.assetPath,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback(),
    );
    final url = room.imageUrl;
    return Semantics(
      label:
          '${url != null && url.isNotEmpty ? 'Photo' : 'Illustration'} of ${room.name}',
      image: true,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              cacheWidth:
                  (MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
              errorBuilder: (_, _, _) => bundled(),
            )
          : bundled(),
    );
  }
}

class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.isError = false, this.icon});
  final String message;
  final bool isError;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFFFFEDE8) : AppColors.mint,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon ?? (isError ? Icons.info_outline : Icons.schedule_outlined),
          size: 20,
          color: isError ? const Color(0xFF9C3E28) : AppColors.accent,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isError ? const Color(0xFF9C3E28) : AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.event_available_outlined,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 38, color: AppColors.accent),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, height: 1.6),
        ),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    ),
  );
}

class DetailLine extends StatelessWidget {
  const DetailLine(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class AvailabilityTimeline extends StatelessWidget {
  const AvailabilityTimeline({
    super.key,
    required this.intervals,
    required this.date,
  });
  final List<BusyInterval> intervals;
  final String date;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _legend(AppColors.available, 'Available'),
            _legend(const Color(0xFFB6C1CF), 'Reserved'),
          ],
        ),
        const SizedBox(height: 18),
        _period('Morning', 480, 720),
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(Icons.coffee_outlined, size: 15, color: AppColors.muted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                '12–1 PM · Lunch break',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _period('Afternoon', 780, 960),
        if (intervals.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Reserved: ${intervals.map((i) => '${timeLabel(i.startMinute)}–${timeLabel(i.endMinute)}').join(', ')}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _legend(Color color, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    ],
  );
  Widget _period(String name, int start, int end) {
    final now = facultyNow();
    final pastMinute = date.compareTo(dayKey(now)) < 0
        ? 1440
        : dayKey(now) == date
        ? now.hour * 60 + now.minute
        : 0;
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 4,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              '${timeLabel(start)} – ${timeLabel(end)}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 18,
            child: Row(
              children: List.generate(end - start, (offset) {
                final minute = start + offset;
                final busy = intervals.any(
                  (i) => minute >= i.startMinute && minute < i.endMinute,
                );
                return Expanded(
                  child: ColoredBox(
                    color: minute < pastMinute
                        ? AppColors.line
                        : busy
                        ? const Color(0xFFB6C1CF)
                        : AppColors.available,
                    child: const SizedBox.expand(),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
