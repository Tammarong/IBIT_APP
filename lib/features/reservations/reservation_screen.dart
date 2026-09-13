import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/booking_time.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';
import 'reservation_controller.dart';

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
  late Stream<Map<String, List<BusyInterval>>> _availability = widget.rooms
      .watchAvailability(dayKey(_date));
  String? _validationError;
  @override
  void dispose() {
    _purpose.dispose();
    _controller.dispose();
    super.dispose();
  }

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
        } else {
          _end = time.hour * 60 + time.minute;
        }
        _validationError = null;
      });
    }
  }

  Future<void> _review(List<BusyInterval> busy) async {
    if (!_form.currentState!.validate()) return;
    if (_start == null || _end == null) {
      setState(() => _validationError = 'Choose a start time and an end time.');
      return;
    }
    final retrying = _controller.isRetryOf(
      roomId: widget.room.id,
      date: dayKey(_date),
      startMinute: _start!,
      endMinute: _end!,
      purpose: _purpose.text.trim(),
    );
    // A lost response can leave our own reservation on the availability timeline.
    // Let the server resolve an identical retry by its original request ID.
    final error = retrying
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
      backgroundColor: AppColors.cream,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Eyebrow('One last look'),
              const SizedBox(height: 8),
              Text(
                'Your room is almost yours.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              DetailLine('Room', widget.room.name),
              DetailLine('Date', dateLabel(dayKey(_date))),
              DetailLine('Time', '${timeLabel(_start!)} – ${timeLabel(_end!)}'),
              DetailLine('Purpose', _purpose.text.trim()),
              const SizedBox(height: 16),
              const Notice(
                'Your reservation will be confirmed immediately. You can cancel any time before it starts.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('confirm_reservation'),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm reservation'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Back to editing'),
                ),
              ),
            ],
          ),
        ),
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
    builder: (context, _) => PopScope(
      canPop: !_controller.busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reserve a room', style: TextStyle(fontSize: 16)),
        ),
        body: StreamBuilder<Map<String, List<BusyInterval>>>(
          key: ValueKey(dayKey(_date)),
          stream: _availability,
          builder: (context, snapshot) {
            final busy = snapshot.data?[widget.room.id] ?? <BusyInterval>[];
            return Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 86,
                          child: RoomArtwork(room: widget.room, height: 82),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Eyebrow('Your chosen space'),
                            const SizedBox(height: 6),
                            Text(
                              widget.room.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              widget.room.subtitle,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Make it your time.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A quick catch-up or a deep-work session.\nChoose the time that works for you.',
                    style: TextStyle(color: AppColors.muted, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  const Eyebrow('01 / Choose a date'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('reservation_date'),
                    onPressed: _controller.busy
                        ? null
                        : () async {
                            final date = await pickBookingDate(context, _date);
                            if (date != null && mounted) {
                              setState(() {
                                _date = dateOnly(date);
                                _availability = widget.rooms.watchAvailability(
                                  dayKey(_date),
                                );
                                _validationError = null;
                              });
                            }
                          },
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(dateLabel(dayKey(_date))),
                  ),
                  const SizedBox(height: 24),
                  const Eyebrow('02 / Make room in your day'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _TimeField(
                        label: 'Start time',
                        value: _start == null
                            ? 'Select time'
                            : timeLabel(_start!),
                        onTap: _controller.busy ? null : () => _pickTime(true),
                        fieldKey: const Key('start_time'),
                      ),
                      _TimeField(
                        label: 'End time',
                        value: _end == null ? 'Select time' : timeLabel(_end!),
                        onTap: _controller.busy ? null : () => _pickTime(false),
                        fieldKey: const Key('end_time'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '8 AM–12 PM or 1–4 PM · Bangkok time',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),
                  if (snapshot.hasError)
                    const Notice(
                      'We couldn’t load the schedule. Check your connection and reopen this room to try again.',
                      isError: true,
                    )
                  else if (!snapshot.hasData)
                    const Center(child: CircularProgressIndicator())
                  else
                    AvailabilityTimeline(intervals: busy, date: dayKey(_date)),
                  const SizedBox(height: 28),
                  const Eyebrow('03 / What brings you here?'),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('booking_purpose'),
                    controller: _purpose,
                    enabled: !_controller.busy,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Booking purpose',
                      hintText: 'e.g. Final-year project discussion',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Add a short purpose for your reservation.'
                        : null,
                  ),
                  if (_validationError != null ||
                      _controller.error != null) ...[
                    const SizedBox(height: 12),
                    Notice(
                      _validationError ?? _controller.error!,
                      isError: true,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('review_reservation'),
                    onPressed:
                        _controller.busy ||
                            !snapshot.hasData ||
                            snapshot.hasError
                        ? null
                        : () => _review(busy),
                    child: _controller.busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Instant confirmation. A little more time for what matters.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.fieldKey,
  });
  final String label, value;
  final VoidCallback? onTap;
  final Key fieldKey;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 60) / 2,
    child: OutlinedButton(
      key: fieldKey,
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        backgroundColor: Colors.white,
        alignment: Alignment.centerLeft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  );
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(automaticallyImplyLeading: false),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mint,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.teal,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(child: Eyebrow('You’re all set')),
          const SizedBox(height: 12),
          Text(
            'Space secured.\nIdeas welcome.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Your reservation is confirmed.\nWe’ll leave the good ideas to you.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.6),
          ),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                RoomArtwork(room: room, height: 160),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        room.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      DetailLine('Date', dateLabel(reservation.date)),
                      DetailLine(
                        'Time',
                        '${timeLabel(reservation.startMinute)} – ${timeLabel(reservation.endMinute)}',
                      ),
                      const Divider(),
                      DetailLine('Reference', reservation.reference),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            key: const Key('view_bookings'),
            onPressed: () {
              onBooked();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('View my bookings'),
          ),
          const SizedBox(height: 8),
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
