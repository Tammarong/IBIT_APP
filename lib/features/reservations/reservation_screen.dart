import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/booking_time.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';
import 'reservation_controller.dart';

const _purposeIdeas = [
  'Group project',
  'Study session',
  'Club meeting',
  'Tutoring',
];

class ReservationScreen extends StatefulWidget {
  const ReservationScreen({
    super.key,
    required this.room,
    required this.date,
    required this.rooms,
    required this.reservations,
    required this.onBooked,
  });
  final Room room;
  final DateTime date;
  final RoomRepository rooms;
  final ReservationRepository reservations;
  final VoidCallback onBooked;
  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  late DateTime _date = widget.date;
  int? _start;
  int? _end;
  final _purpose = TextEditingController();
  final _form = GlobalKey<FormState>();
  late final _controller = ReservationController(widget.reservations);

  /// Availability tagged with its date so a previous day's data is never
  /// shown while the newly selected day loads.
  late Stream<(String, Map<String, List<BusyInterval>>)> _availability =
      _watch();
  String? _validationError;

  Stream<(String, Map<String, List<BusyInterval>>)> _watch() {
    final date = dayKey(_date);
    return widget.rooms
        .watchAvailability(date)
        .map((availability) => (date, availability));
  }

  @override
  void dispose() {
    _purpose.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _setDate(DateTime date) => setState(() {
    _date = dateOnly(date);
    _availability = _watch();
    _validationError = null;
  });

  Future<void> _pickTime(bool start) async {
    final minute = start
        ? _start ?? 480
        : _end ?? (_start == null ? 540 : (_start! + 60).clamp(480, 960));
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: start ? 'Choose start time' : 'Choose end time',
    );
    if (time != null && mounted) {
      setState(() {
        if (start) {
          _start = time.hour * 60 + time.minute;
          if (_end == null || _end! <= _start!) {
            final sessionEnd = _start! < BookingTime.morningEnd
                ? BookingTime.morningEnd
                : BookingTime.afternoonEnd;
            _end = (_start! + 60).clamp(_start! + 1, sessionEnd).toInt();
          }
        } else {
          _end = time.hour * 60 + time.minute;
        }
        _validationError = null;
      });
    }
  }

  /// Up to six free one-hour slots on the half hour (30 minutes if no hour
  /// is left).
  List<(int, int)> _suggestedSlots(List<BusyInterval> busy) {
    final windows = BookingTime.freeWindows(dayKey(_date), busy);
    List<(int, int)> collect(int duration) => [
      for (final (from, to) in windows)
        for (
          var start = (from + 29) ~/ 30 * 30;
          start + duration <= to;
          start += 30
        )
          (start, start + duration),
    ].take(6).toList();
    final hours = collect(60);
    return hours.isNotEmpty ? hours : collect(30);
  }

  void _selectSlot((int, int) slot) => setState(() {
    _start = slot.$1;
    _end = slot.$2;
    _validationError = null;
  });

  bool get _retrying =>
      _start != null &&
      _end != null &&
      _controller.isRetryOf(
        roomId: widget.room.id,
        date: dayKey(_date),
        startMinute: _start!,
        endMinute: _end!,
        purpose: _purpose.text.trim(),
      );

  /// The one problem to show beside the primary action, if any.
  String? _issue(List<BusyInterval> busy) {
    if (_validationError != null) return _validationError;
    // A lost response can leave our own reservation on the availability
    // timeline. Let the server resolve an identical retry by its request ID.
    if (_start != null && _end != null && !_retrying) {
      final issue = BookingTime.validate(
        date: dayKey(_date),
        startMinute: _start!,
        endMinute: _end!,
        busy: busy,
      );
      if (issue != null) return issue;
    }
    return _controller.error;
  }

  Future<void> _review(List<BusyInterval> busy) async {
    if (!_form.currentState!.validate()) return;
    if (_start == null || _end == null) {
      setState(() => _validationError = 'Choose a start time and an end time.');
      return;
    }
    final error = _retrying
        ? null
        : BookingTime.validate(
            date: dayKey(_date),
            startMinute: _start!,
            endMinute: _end!,
            busy: busy,
          );
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }
    setState(() => _validationError = null);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ReviewSheet(
        room: widget.room,
        date: dayKey(_date),
        start: _start!,
        end: _end!,
        purpose: _purpose.text.trim(),
      ),
    );
    if (confirmed != true || !mounted) return;
    final reservation = await _controller.reserve(
      roomId: widget.room.id,
      date: dayKey(_date),
      startMinute: _start!,
      endMinute: _end!,
      purpose: _purpose.text.trim(),
    );
    if (reservation != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReservationSuccessScreen(
            room: widget.room,
            reservation: reservation,
            onBooked: widget.onBooked,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) =>
        StreamBuilder<(String, Map<String, List<BusyInterval>>)>(
          stream: _availability,
          builder: (context, snapshot) {
            final loaded =
                !snapshot.hasError && snapshot.data?.$1 == dayKey(_date);
            final busy = loaded
                ? snapshot.data!.$2[widget.room.id] ?? <BusyInterval>[]
                : <BusyInterval>[];
            return PopScope(
              canPop: !_controller.busy,
              child: Scaffold(
                appBar: AppBar(title: const Text('Reserve a room')),
                body: _body(context, snapshot.hasError, loaded, busy),
                bottomNavigationBar: _actionBar(context, loaded, busy),
              ),
            );
          },
        ),
  );

  Widget _body(
    BuildContext context,
    bool failed,
    bool loaded,
    List<BusyInterval> busy,
  ) {
    final text = Theme.of(context).textTheme;
    final locked = _controller.busy;
    final hasRange = _start != null && _end != null && _end! > _start!;
    final suggested = loaded ? _suggestedSlots(busy) : <(int, int)>[];
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.xs,
          AppSpace.gutter,
          AppSpace.xl,
        ),
        children: [
          SurfaceCard(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: RoomArtwork(room: widget.room, width: 64, height: 64),
                ),
                const SizedBox(width: AppSpace.md + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.room.name, style: text.titleMedium),
                      Text(
                        widget.room.subtitle,
                        style: text.bodySmall!.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Date', step: 1),
          const SizedBox(height: AppSpace.md),
          DayStepper(
            date: _date,
            onChanged: _setDate,
            pickerKey: const Key('reservation_date'),
            enabled: !locked,
          ),
          const SizedBox(height: AppSpace.xxl - 4),
          const SectionHeader(
            'Time',
            step: 2,
            subtitle: '8:00 AM–12:00 PM or 1:00–4:00 PM · Bangkok time',
          ),
          const SizedBox(height: AppSpace.lg),
          if (failed)
            const Notice(
              'We couldn’t load the schedule. Check your connection and reopen this room to try again.',
              isError: true,
            )
          else if (!loaded)
            const Padding(
              padding: EdgeInsets.all(AppSpace.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            AvailabilityTimeline(
              intervals: busy,
              date: dayKey(_date),
              selection: hasRange ? (_start!, _end!) : null,
              showFreeTimes: false,
            ),
            const SizedBox(height: AppSpace.lg + 4),
            Text('Suggested times', style: text.titleSmall),
            const SizedBox(height: AppSpace.sm),
            if (suggested.isEmpty)
              Text(
                'No free time slots remain on this day. Try another weekday.',
                style: text.bodyMedium!.copyWith(color: AppColors.muted),
              )
            else
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  for (final slot in suggested)
                    ChoiceChip(
                      label: Text(rangeLabel(slot.$1, slot.$2)),
                      selected: _start == slot.$1 && _end == slot.$2,
                      onSelected: locked ? null : (_) => _selectSlot(slot),
                    ),
                ],
              ),
          ],
          const SizedBox(height: AppSpace.lg + 4),
          Text('Or set exact times', style: text.titleSmall),
          const SizedBox(height: AppSpace.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final start = _TimeField(
                label: 'Start time',
                value: _start == null ? null : timeLabel(_start!),
                onTap: locked ? null : () => _pickTime(true),
                fieldKey: const Key('start_time'),
              );
              final end = _TimeField(
                label: 'End time',
                value: _end == null ? null : timeLabel(_end!),
                onTap: locked ? null : () => _pickTime(false),
                fieldKey: const Key('end_time'),
              );
              final stacked =
                  constraints.maxWidth /
                      MediaQuery.textScalerOf(context).scale(1) <
                  280;
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        start,
                        const SizedBox(height: AppSpace.md),
                        end,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: start),
                        const SizedBox(width: AppSpace.md),
                        Expanded(child: end),
                      ],
                    );
            },
          ),
          const SizedBox(height: AppSpace.xxl - 4),
          const SectionHeader(
            'Purpose',
            step: 3,
            subtitle: 'A short note about how you’ll use the room.',
          ),
          const SizedBox(height: AppSpace.md),
          TextFormField(
            key: const Key('booking_purpose'),
            controller: _purpose,
            enabled: !locked,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => currentLength > 400
                ? Text('$currentLength/$maxLength')
                : null,
            decoration: const InputDecoration(
              labelText: 'Booking purpose',
              hintText: 'e.g. Final-year project discussion',
              alignLabelWithHint: true,
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Add a short purpose for your reservation.'
                : null,
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final idea in _purposeIdeas)
                ActionChip(
                  label: Text(idea),
                  onPressed: locked
                      ? null
                      : () => setState(() {
                          _purpose.text = idea;
                          _purpose.selection = TextSelection.collapsed(
                            offset: idea.length,
                          );
                        }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBar(
    BuildContext context,
    bool loaded,
    List<BusyInterval> busy,
  ) {
    final text = Theme.of(context).textTheme;
    final issue = _issue(busy);
    final ready = _start != null && _end != null && issue == null;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.md,
            AppSpace.gutter,
            AppSpace.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (issue != null) ...[
                Notice(issue, isError: true),
                const SizedBox(height: AppSpace.md - 2),
              ] else if (ready) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      size: 20,
                      color: AppColors.available,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        '${relativeDayLabel(_date)} · ${rangeLabel(_start!, _end!)} · '
                        '${BookingTime.durationLabel(_end! - _start!)}',
                        style: text.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md - 2),
              ],
              FilledButton(
                key: const Key('review_reservation'),
                onPressed: _controller.busy || !loaded
                    ? null
                    : () => _review(busy),
                child: _controller.busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.muted,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Review reservation',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(width: AppSpace.sm + 2),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.fieldKey,
  });
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Key fieldKey;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return OutlinedButton(
      key: fieldKey,
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        alignment: Alignment.centerLeft,
        side: BorderSide(
          color: value == null ? AppColors.line : AppColors.ink,
          width: value == null ? 1 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.bodySmall!.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value ?? 'Select time',
                  style: text.titleMedium!.copyWith(
                    color: value == null ? AppColors.muted : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.schedule_rounded, size: 20, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _ReviewSheet extends StatelessWidget {
  const _ReviewSheet({
    required this.room,
    required this.date,
    required this.start,
    required this.end,
    required this.purpose,
  });
  final Room room;
  final String date;
  final int start, end;
  final String purpose;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Review your reservation', style: text.headlineSmall),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Check the details, then confirm.',
            style: text.bodyMedium!.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpace.lg + 4),
          SurfaceCard(
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: RoomArtwork(room: room, width: 52, height: 52),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(room.name, style: text.titleMedium),
                          Text(
                            room.subtitle,
                            style: text.bodySmall!.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                const Divider(),
                const SizedBox(height: AppSpace.xs),
                DetailLine('Date', dateLabel(date)),
                DetailLine('Time', rangeLabel(start, end)),
                DetailLine('Duration', BookingTime.durationLabel(end - start)),
                DetailLine('Purpose', purpose),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          const Notice(
            'Confirmed instantly. You can cancel any time before it starts.',
            tone: NoticeTone.success,
          ),
          const SizedBox(height: AppSpace.lg + 4),
          FilledButton(
            key: const Key('confirm_reservation'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm reservation'),
          ),
          const SizedBox(height: AppSpace.xs),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back to editing'),
          ),
        ],
      ),
    );
  }
}

class ReservationSuccessScreen extends StatelessWidget {
  const ReservationSuccessScreen({
    super.key,
    required this.room,
    required this.reservation,
    required this.onBooked,
  });
  final Room room;
  final Reservation reservation;
  final VoidCallback onBooked;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.xxl,
            AppSpace.gutter,
            AppSpace.xxl,
          ),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.availableTint,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.available,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg + 4),
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                'Reservation confirmed',
                textAlign: TextAlign.center,
                style: text.headlineMedium,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'The room is yours. If your plans change, cancel from My bookings before it starts.',
              textAlign: TextAlign.center,
              style: text.bodyMedium!.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpace.xl),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RoomArtwork(room: room, height: 140),
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.name, style: text.titleLarge),
                        const SizedBox(height: AppSpace.sm),
                        DetailLine('Date', dateLabel(reservation.date)),
                        DetailLine(
                          'Time',
                          rangeLabel(
                            reservation.startMinute,
                            reservation.endMinute,
                          ),
                        ),
                        DetailLine(
                          'Duration',
                          BookingTime.durationLabel(
                            reservation.endMinute - reservation.startMinute,
                          ),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        const Divider(),
                        const SizedBox(height: AppSpace.xs),
                        DetailLine('Reference', reservation.reference),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            FilledButton(
              key: const Key('view_bookings'),
              onPressed: () {
                onBooked();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('View my bookings'),
            ),
            const SizedBox(height: AppSpace.xs),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Explore more rooms'),
            ),
          ],
        ),
      ),
    );
  }
}
