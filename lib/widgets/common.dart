import 'dart:math' as math;

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

/// The weekday before ([direction] -1) or after (1) [date].
DateTime shiftWeekday(DateTime date, int direction) {
  var day = dateOnly(date).add(Duration(days: direction));
  while (day.weekday > 5) {
    day = day.add(Duration(days: direction));
  }
  return day;
}

DateTime initialBookingDate() => BookingTime.nextBookableDate();

String timeLabel(int minute) => BookingTime.formatMinute(minute);
String rangeLabel(int start, int end) => BookingTime.formatRange(start, end);
String dateLabel(String date) =>
    DateFormat('EEE, d MMM yyyy').format(DateTime.parse(date));

String roomTypeLabel(Room room) => switch (room.category) {
  'computer' => 'Computer room',
  'classroom' => 'Classroom',
  _ => 'Specialized room',
};

/// "Today", "Tomorrow" or "Wed, 7 Oct".
String relativeDayLabel(DateTime date) {
  final today = dateOnly(facultyNow());
  final day = dateOnly(date);
  if (day == today) return 'Today';
  if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
  return DateFormat('EEE, d MMM').format(day);
}

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

/// Small uppercase label above a heading or group.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = AppColors.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(
      context,
    ).textTheme.labelSmall!.copyWith(color: color, letterSpacing: 1.2),
  );
}

/// Title for a group of content, optionally numbered as a form step.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.step,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final int? step;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (step != null) ...[
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$step',
              textScaler: TextScaler.noScaling,
              style: text.labelMedium!.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: AppSpace.md - 2),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: text.titleMedium),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: text.bodySmall!.copyWith(color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// White rounded container with a hairline border; the default card.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.onTap,
    this.color = AppColors.surface,
    this.borderColor = AppColors.line,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

enum PillTone { success, neutral, accent, danger, navy }

/// Compact status label. Pair colour with text; never colour alone.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.tone = PillTone.neutral,
    this.icon,
  });
  final String label;
  final PillTone tone;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      PillTone.success => (AppColors.availableTint, AppColors.available),
      PillTone.neutral => (AppColors.panel, AppColors.muted),
      PillTone.accent => (AppColors.accentTint, AppColors.accent),
      PillTone.danger => (AppColors.dangerTint, AppColors.danger),
      PillTone.navy => (AppColors.navyTint, AppColors.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall!.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon tile, small label and value. Used for facts and rules.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.navyTint,
            borderRadius: BorderRadius.circular(AppRadius.md - 2),
          ),
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.bodySmall!.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 1),
              Text(value, style: text.titleSmall),
            ],
          ),
        ),
      ],
    );
  }
}

class RoomArtwork extends StatelessWidget {
  const RoomArtwork({
    super.key,
    required this.room,
    this.height = 210,
    this.width = double.infinity,
  });
  final Room room;
  final double height;
  final double width;
  @override
  Widget build(BuildContext context) {
    Widget placeholder() => SizedBox(
      height: height,
      width: width,
      child: Icon(
        Icons.meeting_room_outlined,
        size: math.min(height * .3, 48),
        color: AppColors.reserved,
      ),
    );
    Widget fadeIn(BuildContext _, Widget child, int? frame, bool loaded) =>
        loaded
        ? child
        : AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: child,
          );
    Widget bundled() => Image.asset(
      room.assetPath,
      height: height,
      width: width,
      fit: BoxFit.cover,
      frameBuilder: fadeIn,
      errorBuilder: (_, _, _) => placeholder(),
    );
    final url = room.imageUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    final logicalWidth = width.isFinite
        ? width
        : MediaQuery.sizeOf(context).width;
    return Semantics(
      label: '${hasPhoto ? 'Photo' : 'Illustration'} of ${room.name}',
      image: true,
      child: ColoredBox(
        color: AppColors.panel,
        child: hasPhoto
            ? Image.network(
                url,
                height: height,
                width: width,
                fit: BoxFit.cover,
                cacheWidth:
                    (logicalWidth * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                frameBuilder: fadeIn,
                errorBuilder: (_, _, _) => bundled(),
              )
            : bundled(),
      ),
    );
  }
}

enum NoticeTone { info, accent, success, error }

/// Inline message box. Errors are announced to screen readers.
class Notice extends StatelessWidget {
  const Notice(
    this.message, {
    super.key,
    this.isError = false,
    this.icon,
    this.tone = NoticeTone.info,
  });
  final String message;
  final bool isError;
  final IconData? icon;
  final NoticeTone tone;
  @override
  Widget build(BuildContext context) {
    final effective = isError ? NoticeTone.error : tone;
    final (background, iconColor, textColor, defaultIcon) = switch (effective) {
      NoticeTone.info => (
        AppColors.navyTint,
        AppColors.ink,
        AppColors.ink,
        Icons.info_outline_rounded,
      ),
      NoticeTone.accent => (
        AppColors.accentTint,
        AppColors.accent,
        AppColors.ink,
        Icons.schedule_rounded,
      ),
      NoticeTone.success => (
        AppColors.availableTint,
        AppColors.available,
        AppColors.ink,
        Icons.check_circle_outline_rounded,
      ),
      NoticeTone.error => (
        AppColors.dangerTint,
        AppColors.danger,
        AppColors.danger,
        Icons.error_outline_rounded,
      ),
    };
    return Semantics(
      liveRegion: effective == NoticeTone.error,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? defaultIcon, size: 20, color: iconColor),
            const SizedBox(width: AppSpace.md - 2),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: textColor,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.navyTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppColors.ink),
          ),
          const SizedBox(height: AppSpace.lg + 4),
          Text(title, textAlign: TextAlign.center, style: text.titleLarge),
          const SizedBox(height: AppSpace.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodyMedium!.copyWith(color: AppColors.muted),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

class DetailLine extends StatelessWidget {
  const DetailLine(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium!.copyWith(color: AppColors.muted),
            ),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: text.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontally scrolling weekday picker. Weekends are never shown.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.start,
    required this.selected,
    required this.onSelected,
    this.count = 10,
  });
  final DateTime start;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final int count;

  static List<DateTime> days(DateTime start, int count) {
    final days = <DateTime>[nextWeekday(start)];
    while (days.length < count) {
      days.add(shiftWeekday(days.last, 1));
    }
    return days;
  }

  static bool shows(DateTime start, DateTime date, {int count = 10}) =>
      days(start, count).any((day) => dayKey(day) == dayKey(date));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final today = dayKey(facultyNow());
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Row(
        children: [
          for (final day in days(start, count))
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.sm),
              child: _tile(
                day,
                text,
                selected: dayKey(day) == dayKey(selected),
                today: dayKey(day) == today,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(
    DateTime day,
    TextTheme text, {
    required bool selected,
    required bool today,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: selected ? AppColors.ink : AppColors.line),
    );
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${today ? 'Today, ' : ''}${DateFormat('EEEE d MMMM').format(day)}',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.ink : AppColors.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: () => onSelected(day),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                children: [
                  Text(
                    today ? 'Today' : DateFormat('EEE').format(day),
                    style: text.labelSmall!.copyWith(
                      color: selected
                          ? Colors.white.withValues(alpha: .8)
                          : today
                          ? AppColors.accent
                          : AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: text.titleLarge!.copyWith(
                      fontSize: 20,
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Previous / pick / next control for moving between bookable weekdays.
class DayStepper extends StatelessWidget {
  const DayStepper({
    super.key,
    required this.date,
    required this.onChanged,
    this.pickerKey,
    this.enabled = true,
  });
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final Key? pickerKey;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final previous = shiftWeekday(date, -1);
    final canGoBack = enabled && !previous.isBefore(dateOnly(facultyNow()));
    Widget arrow(IconData icon, String tooltip, VoidCallback? onPressed) =>
        IconButton.outlined(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            disabledBackgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.line),
            minimumSize: const Size(52, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md + 2),
            ),
          ),
        );
    return Row(
      children: [
        arrow(
          Icons.chevron_left_rounded,
          'Previous weekday',
          canGoBack ? () => onChanged(previous) : null,
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: OutlinedButton.icon(
            key: pickerKey,
            onPressed: !enabled
                ? null
                : () async {
                    final picked = await pickBookingDate(context, date);
                    if (picked != null) onChanged(dateOnly(picked));
                  },
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(dateLabel(dayKey(date)), textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        arrow(
          Icons.chevron_right_rounded,
          'Next weekday',
          enabled ? () => onChanged(shiftWeekday(date, 1)) : null,
        ),
      ],
    );
  }
}

/// Morning and afternoon bars showing free, reserved and elapsed time.
class AvailabilityTimeline extends StatelessWidget {
  const AvailabilityTimeline({
    super.key,
    required this.intervals,
    required this.date,
    this.selection,
    this.showFreeTimes = true,
  });
  final List<BusyInterval> intervals;
  final String date;

  /// Highlights a chosen (start, end) range on the bars.
  final (int, int)? selection;

  /// Lists the free windows below the bars.
  final bool showFreeTimes;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final today = dayKey(facultyNow()) == date;
    final free = BookingTime.freeWindows(date, intervals);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpace.lg,
          runSpacing: AppSpace.xs,
          children: [
            _legend(text, AppColors.available, 'Free'),
            _legend(text, AppColors.reserved, 'Reserved'),
            if (today) _legend(text, AppColors.past, 'Past'),
            if (selection != null) _legend(text, AppColors.ink, 'Your time'),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        _period(
          text,
          'Morning',
          BookingTime.morningStart,
          BookingTime.morningEnd,
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            const Icon(Icons.coffee_outlined, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '12:00–1:00 PM · Lunch break',
                style: text.bodySmall!.copyWith(color: AppColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        _period(
          text,
          'Afternoon',
          BookingTime.afternoonStart,
          BookingTime.afternoonEnd,
        ),
        if (showFreeTimes) ...[
          const SizedBox(height: AppSpace.lg),
          Text('Free times', style: text.titleSmall),
          const SizedBox(height: AppSpace.sm),
          if (free.isEmpty)
            Text(
              'No free time left on this day. Try another weekday.',
              style: text.bodyMedium!.copyWith(color: AppColors.muted),
            )
          else
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final (start, end) in free)
                  StatusPill(rangeLabel(start, end), tone: PillTone.success),
              ],
            ),
        ],
      ],
    );
  }

  Widget _legend(TextTheme text, Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: text.bodySmall!.copyWith(color: AppColors.muted)),
    ],
  );

  Widget _period(TextTheme text, String name, int start, int end) {
    final ticks = end - start <= 180
        ? [start, start + (end - start) ~/ 2, end]
        : [start, start + 120, end];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: AppSpace.lg,
          runSpacing: 2,
          children: [
            Text(name, style: text.titleSmall),
            Text(
              rangeLabel(start, end),
              style: text.bodySmall!.copyWith(color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Semantics(
          label:
              '$name availability from ${timeLabel(start)} to ${timeLabel(end)}',
          child: AvailabilityBar(
            date: date,
            start: start,
            end: end,
            intervals: intervals,
            selection: selection,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (index, minute) in ticks.indexed)
              Expanded(
                child: Text(
                  timeLabel(minute).replaceFirst(':00', ''),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  textAlign: switch (index) {
                    0 => TextAlign.start,
                    1 => TextAlign.center,
                    _ => TextAlign.end,
                  },
                  style: text.bodySmall!.copyWith(color: AppColors.muted),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One session drawn as free, reserved and elapsed time.
class AvailabilityBar extends StatelessWidget {
  const AvailabilityBar({
    super.key,
    required this.date,
    required this.start,
    required this.end,
    required this.intervals,
    this.selection,
    this.height = 26,
    this.dividers = true,
  });
  final String date;
  final int start, end;
  final List<BusyInterval> intervals;
  final (int, int)? selection;
  final double height;

  /// Draws faint 30-minute ticks; turn off for small bars.
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    final now = facultyNow();
    final elapsed = date.compareTo(dayKey(now)) < 0
        ? 1440
        : dayKey(now) == date
        ? now.hour * 60 + now.minute
        : 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height > 10 ? AppRadius.sm : 3),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _AvailabilityBarPainter(
            start: start,
            end: end,
            pastMinute: elapsed,
            intervals: intervals,
            selection: selection,
            dividers: dividers,
          ),
        ),
      ),
    );
  }
}

class _AvailabilityBarPainter extends CustomPainter {
  const _AvailabilityBarPainter({
    required this.start,
    required this.end,
    required this.pastMinute,
    required this.intervals,
    required this.selection,
    required this.dividers,
  });

  final int start;
  final int end;
  final int pastMinute;
  final List<BusyInterval> intervals;
  final (int, int)? selection;
  final bool dividers;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.available);
    _range(canvas, size, start, pastMinute, Paint()..color = AppColors.past);
    final reserved = Paint()..color = AppColors.reserved;
    for (final interval in intervals) {
      _range(canvas, size, interval.startMinute, interval.endMinute, reserved);
    }
    final divider = Paint()
      ..color = Colors.white.withValues(alpha: .55)
      ..strokeWidth = 1;
    for (var minute = start + 30; dividers && minute < end; minute += 30) {
      final x = (minute - start) / (end - start) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), divider);
    }
    final chosen = selection;
    if (chosen != null) {
      final rect = _rect(size, chosen.$1, chosen.$2);
      if (rect != null) {
        final shape = RRect.fromRectAndRadius(
          rect.deflate(1.5),
          const Radius.circular(4),
        );
        canvas.drawRRect(
          shape,
          Paint()..color = AppColors.ink.withValues(alpha: .82),
        );
        canvas.drawRRect(
          shape,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  Rect? _rect(Size size, int from, int to) {
    final left = from.clamp(start, end), right = to.clamp(start, end);
    if (right <= left) return null;
    return Rect.fromLTRB(
      (left - start) / (end - start) * size.width,
      0,
      (right - start) / (end - start) * size.width,
      size.height,
    );
  }

  void _range(Canvas canvas, Size size, int from, int to, Paint paint) {
    final rect = _rect(size, from, to);
    if (rect != null) canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _AvailabilityBarPainter oldDelegate) =>
      start != oldDelegate.start ||
      end != oldDelegate.end ||
      pastMinute != oldDelegate.pastMinute ||
      intervals != oldDelegate.intervals ||
      selection != oldDelegate.selection ||
      dividers != oldDelegate.dividers;
}
