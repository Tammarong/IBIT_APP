import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/firebase_config.dart';
import '../../core/theme.dart';
import '../../core/booking_time.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/itd_brand.dart';

enum _Filter {
  upcoming('Upcoming'),
  past('Past'),
  cancelled('Cancelled');

  const _Filter(this.label);
  final String label;

  bool includes(Reservation booking) => switch (this) {
    _Filter.cancelled => booking.isCancelled,
    _Filter.past => !booking.isCancelled && BookingTime.hasEnded(booking),
    _Filter.upcoming => !booking.isCancelled && !BookingTime.hasEnded(booking),
  };
}

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({
    super.key,
    required this.uid,
    required this.rooms,
    required this.reservations,
    required this.onExplore,
  });
  final String uid;
  final RoomRepository rooms;
  final ReservationRepository reservations;
  final VoidCallback onExplore;
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  _Filter _filter = _Filter.upcoming;
  late Stream<List<Reservation>> _bookings = widget.reservations
      .watchMyReservations(widget.uid);
  late final _rooms = widget.rooms.watchRooms();
  final Set<String> _cancelling = {};
  late final Timer _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Future<void> _cancel(Reservation booking, String roomName) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.event_busy_rounded, color: AppColors.danger),
        title: const Text('Cancel this booking?'),
        content: Text(
          '$roomName · ${dateLabel(booking.date)} · '
          '${rangeLabel(booking.startMinute, booking.endMinute)}\n\n'
          'The time becomes available to others right away.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (answer != true || !mounted) return;
    setState(() => _cancelling.add(booking.id));
    void tell(String message) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }

    try {
      await widget.reservations.cancelReservation(booking.id);
      tell('Booking cancelled. The room is available again.');
    } on ReservationException catch (error) {
      tell(error.message);
    } catch (_) {
      tell('Couldn’t cancel. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _cancelling.remove(booking.id));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: StreamBuilder<List<Room>>(
      stream: _rooms,
      builder: (context, roomSnapshot) => StreamBuilder<List<Reservation>>(
        stream: _bookings,
        builder: (context, snapshot) {
          final all = snapshot.data ?? const <Reservation>[];
          final rooms = {
            for (final room in roomSnapshot.data ?? const <Room>[])
              room.id: room,
          };
          return CustomScrollView(
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.lg,
                  AppSpace.gutter,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: ScreenHeader(
                    title: 'My bookings',
                    subtitle: 'Your upcoming and past room reservations.',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.lg + 4,
                    AppSpace.gutter,
                    AppSpace.lg,
                  ),
                  child: Row(
                    children: [
                      for (final filter in _Filter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpace.sm),
                          child: _FilterChip(
                            filter: filter,
                            count: all.where(filter.includes).length,
                            selected: _filter == filter,
                            onSelected: () => setState(() => _filter = filter),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ..._content(snapshot, all, rooms),
            ],
          );
        },
      ),
    ),
  );

  List<Widget> _content(
    AsyncSnapshot<List<Reservation>> snapshot,
    List<Reservation> all,
    Map<String, Room> rooms,
  ) {
    if (snapshot.hasError) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            title: 'Your bookings couldn’t load',
            message: 'Check your internet connection, then try again.',
            icon: Icons.wifi_off_rounded,
            action: OutlinedButton.icon(
              onPressed: () => setState(
                () => _bookings = widget.reservations.watchMyReservations(
                  widget.uid,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ),
      ];
    }
    if (!snapshot.hasData) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    final bookings = all.where(_filter.includes).toList()
      ..sort(
        (a, b) =>
            '${a.date}${a.startMinute.toString().padLeft(4, '0')}'.compareTo(
              '${b.date}${b.startMinute.toString().padLeft(4, '0')}',
            ) *
            (_filter == _Filter.upcoming ? 1 : -1),
      );
    if (bookings.isEmpty) {
      final (title, message) = switch (_filter) {
        _Filter.past => (
          'No past bookings',
          'Reservations you have used will appear here.',
        ),
        _Filter.cancelled => (
          'No cancelled bookings',
          'Bookings you cancel are kept here for reference.',
        ),
        _Filter.upcoming =>
          EmulatorConfig.bookingsAvailable
              ? (
                  'No upcoming bookings',
                  'Find a free room and reserve a time in a few taps.',
                )
              : (
                  'Online booking is being prepared',
                  'You can browse live ITD room information now. Reservations will appear here when booking opens.',
                ),
      };
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            title: title,
            message: message,
            icon: _filter == _Filter.cancelled
                ? Icons.event_busy_outlined
                : Icons.event_available_outlined,
            action: _filter == _Filter.upcoming
                ? FilledButton.icon(
                    onPressed: widget.onExplore,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Find a room'),
                  )
                : null,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          0,
          AppSpace.gutter,
          AppSpace.xxl,
        ),
        sliver: SliverList.separated(
          itemCount: bookings.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final room = rooms[booking.roomId];
            return _BookingCard(
              booking: booking,
              roomName: room?.name ?? booking.roomId,
              next:
                  _filter == _Filter.upcoming &&
                  index == 0 &&
                  !BookingTime.hasStarted(booking),
              cancelling: _cancelling.contains(booking.id),
              onCancel: () => _cancel(booking, room?.name ?? booking.roomId),
            );
          },
        ),
      ),
    ];
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onSelected,
  });
  final _Filter filter;
  final int count;
  final bool selected;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    selected: selected,
    onSelected: (_) => onSelected(),
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(filter.label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: .2)
                  : AppColors.panel,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              semanticsLabel: '$count bookings',
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: selected ? Colors.white : AppColors.muted,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.roomName,
    required this.next,
    required this.cancelling,
    required this.onCancel,
  });
  final Reservation booking;
  final String roomName;

  /// The soonest upcoming booking; shown with a countdown.
  final bool next;
  final bool cancelling;
  final VoidCallback onCancel;

  String _countdown() {
    final difference = BookingTime.instant(
      booking.date,
      booking.startMinute,
    ).difference(DateTime.now().toUtc());
    if (difference.inMinutes < 60) {
      return 'Starts in ${difference.inMinutes.clamp(1, 59)} min';
    }
    if (difference.inHours < 24) return 'Starts in ${difference.inHours} hr';
    if (difference.inDays < 7) {
      return 'Starts in ${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'}';
    }
    return 'Next booking';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final started = BookingTime.hasStarted(booking);
    final ended = BookingTime.hasEnded(booking);
    final (status, tone) = booking.isCancelled
        ? ('Cancelled', PillTone.neutral)
        : ended
        ? ('Completed', PillTone.neutral)
        : started
        ? ('In progress', PillTone.accent)
        : ('Confirmed', PillTone.success);
    final day = BookingTime.parseDate(booking.date);
    final faded = booking.isCancelled || ended;
    return SurfaceCard(
      borderColor: next ? AppColors.ink.withValues(alpha: .35) : AppColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (next) ...[
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _countdown(),
                    style: text.labelMedium!.copyWith(color: AppColors.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 58,
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                  decoration: BoxDecoration(
                    color: next
                        ? AppColors.ink
                        : faded
                        ? AppColors.panel
                        : AppColors.navyTint,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('MMM').format(day).toUpperCase(),
                        style: text.labelSmall!.copyWith(
                          color: next ? Colors.white70 : AppColors.muted,
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: text.headlineSmall!.copyWith(
                          height: 1.1,
                          color: next
                              ? Colors.white
                              : faded
                              ? AppColors.muted
                              : AppColors.ink,
                        ),
                      ),
                      Text(
                        DateFormat('EEE').format(day),
                        style: text.labelSmall!.copyWith(
                          color: next ? Colors.white70 : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(roomName, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${relativeDayLabel(day)} · '
                      '${rangeLabel(booking.startMinute, booking.endMinute)}',
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      booking.purpose,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium!.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      'Ref. ${booking.reference}',
                      style: text.bodySmall!.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          const Divider(),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpace.md,
            runSpacing: AppSpace.sm,
            children: [
              StatusPill(status, tone: tone),
              if (!booking.isCancelled && !started)
                TextButton.icon(
                  onPressed: cancelling ? null : onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: cancelling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.danger,
                          ),
                        )
                      : const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancel reservation'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
