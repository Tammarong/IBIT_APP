import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/booking_time.dart';
import '../../core/firebase_config.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/itd_brand.dart';
import 'room_detail_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({
    super.key,
    required this.rooms,
    required this.reservations,
    required this.onBooked,
  });
  final RoomRepository rooms;
  final ReservationRepository reservations;
  final VoidCallback onBooked;
  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

const _categories = [
  ('all', 'All rooms'),
  ('classroom', 'Classrooms'),
  ('computer', 'Computer rooms'),
  ('other', 'Other'),
];

class _RoomsScreenState extends State<RoomsScreen> with WidgetsBindingObserver {
  late DateTime _date = initialBookingDate();
  late DateTime _stripStart = _date;
  late Stream<List<Room>> _rooms = widget.rooms.watchRooms();
  late Stream<Map<String, List<BusyInterval>>> _availability = widget.rooms
      .watchAvailability(dayKey(_date));
  bool _availableOnly = false;
  String _category = 'all';
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_date.isBefore(dateOnly(facultyNow()))) {
        _stripStart = initialBookingDate();
        _select(_stripStart);
      } else {
        setState(() {});
      }
    }
  }

  void _select(DateTime date) => setState(() {
    _date = dateOnly(date);
    if (!DayStrip.shows(_stripStart, _date)) _stripStart = _date;
    _availability = widget.rooms.watchAvailability(dayKey(_date));
  });
  void _retry() => setState(() {
    _rooms = widget.rooms.watchRooms();
    _availability = widget.rooms.watchAvailability(dayKey(_date));
  });
  void _clearFilters() => setState(() {
    _search.clear();
    _category = 'all';
    _availableOnly = false;
  });
  bool get _filtered =>
      _search.text.trim().isNotEmpty || _category != 'all' || _availableOnly;

  bool _matches(Room room, String query) {
    if (!room.listed) return false;
    if (query.isNotEmpty &&
        ![
          room.name,
          room.subtitle,
          room.officialName ?? '',
          ...room.facilities,
        ].any((value) => value.toLowerCase().contains(query))) {
      return false;
    }
    return switch (_category) {
      'all' => true,
      'other' => room.category != 'classroom' && room.category != 'computer',
      _ => room.category == _category,
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                title: 'Find a room',
                subtitle: 'Choose a weekday to see free rooms.',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.xl - 4,
              AppSpace.sm,
              AppSpace.xs,
            ),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(_date),
                    style: text.titleSmall,
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final date = await pickBookingDate(context, _date);
                      if (date != null) _select(date);
                    },
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Pick date'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: DayStrip(
              start: _stripStart,
              selected: _date,
              onSelected: _select,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.lg,
              AppSpace.gutter,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by room, e.g. 3A02',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.md,
                AppSpace.gutter,
                AppSpace.lg,
              ),
              child: Row(
                children: [
                  for (final (value, label) in _categories)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpace.sm),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _category == value,
                        onSelected: (_) => setState(() => _category = value),
                      ),
                    ),
                  FilterChip(
                    label: const Text('Available only'),
                    selected: _availableOnly,
                    onSelected: (value) =>
                        setState(() => _availableOnly = value),
                    avatar: Icon(
                      _availableOnly
                          ? Icons.check_rounded
                          : Icons.event_available_outlined,
                      color: _availableOnly ? Colors.white : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder<List<Room>>(
            stream: _rooms,
            builder: (context, roomSnapshot) {
              if (roomSnapshot.hasError) {
                return SliverToBoxAdapter(
                  child: EmptyState(
                    title: 'Couldn’t load rooms',
                    message: 'Check your internet connection, then try again.',
                    icon: Icons.wifi_off_rounded,
                    action: OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ),
                );
              }
              if (!roomSnapshot.hasData) {
                return const _RoomListSkeleton();
              }
              if (roomSnapshot.data!.isEmpty) {
                return const SliverToBoxAdapter(
                  child: EmptyState(
                    title: 'Rooms are being prepared',
                    message:
                        'Your faculty’s rooms will appear here once they are ready.',
                    icon: Icons.meeting_room_outlined,
                  ),
                );
              }
              return StreamBuilder<Map<String, List<BusyInterval>>>(
                key: ValueKey(dayKey(_date)),
                stream: _availability,
                builder: (context, snapshot) =>
                    _results(context, roomSnapshot.data!, snapshot),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _results(
    BuildContext context,
    List<Room> allRooms,
    AsyncSnapshot<Map<String, List<BusyInterval>>> snapshot,
  ) {
    final text = Theme.of(context).textTheme;
    final query = _search.text.trim().toLowerCase();
    final known = snapshot.hasData && !snapshot.hasError;
    List<(int, int)> windows(Room room) =>
        BookingTime.freeWindows(dayKey(_date), snapshot.data?[room.id] ?? []);
    final rooms = allRooms
        .where(
          (room) =>
              _matches(room, query) &&
              (!_availableOnly ||
                  (room.bookingEnabled && known && windows(room).isNotEmpty)),
        )
        .toList();
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      sliver: SliverList.list(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: Text(
              '${rooms.length} ${rooms.length == 1 ? 'room' : 'rooms'} · '
              '${relativeDayLabel(_date)}',
              style: text.bodyMedium!.copyWith(color: AppColors.muted),
            ),
          ),
          if (snapshot.hasError)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpace.lg),
              child: Notice(
                'Availability couldn’t be refreshed. Check the room’s schedule before reserving.',
                isError: true,
              ),
            ),
          if (rooms.isEmpty)
            EmptyState(
              title: !snapshot.hasData
                  ? 'Checking availability'
                  : _filtered
                  ? 'No matching rooms'
                  : 'Every room is booked',
              message: !snapshot.hasData
                  ? 'Getting the latest room schedules.'
                  : _filtered
                  ? 'Try another search or category, or show all rooms.'
                  : 'Choose another weekday to find a free room.',
              icon: Icons.search_off_rounded,
              action: _filtered && snapshot.hasData
                  ? OutlinedButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear filters'),
                    )
                  : null,
            ),
          for (final room in rooms)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: RoomCard(
                room: room,
                date: dayKey(_date),
                intervals: known ? snapshot.data![room.id] ?? const [] : null,
                status: _status(room, snapshot, known ? windows(room) : null),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RoomDetailScreen(
                      room: room,
                      date: _date,
                      rooms: widget.rooms,
                      reservations: widget.reservations,
                      onBooked: widget.onBooked,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.sm,
              AppSpace.md,
              AppSpace.sm,
              AppSpace.xxl,
            ),
            child: Text(
              EmulatorConfig.bookingsAvailable
                  ? 'Room names and photos from the official ITD website.\n'
                        'Bookings: Mon–Fri · 8:00 AM–12:00 PM and 1:00–4:00 PM · Bangkok time'
                  : 'Room names and photos from the official ITD website.\n'
                        'Online booking is being prepared.',
              textAlign: TextAlign.center,
              style: text.bodySmall!.copyWith(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  (String, PillTone) _status(
    Room room,
    AsyncSnapshot<Map<String, List<BusyInterval>>> snapshot,
    List<(int, int)>? windows,
  ) {
    if (!room.bookingEnabled) {
      if (room.category != 'classroom' && room.category != 'computer') {
        return ('Information only', PillTone.neutral);
      }
      return (
        EmulatorConfig.bookingsAvailable
            ? 'Booking setup pending'
            : 'Booking coming soon',
        PillTone.neutral,
      );
    }
    if (snapshot.hasError) {
      return ('Couldn’t check availability', PillTone.neutral);
    }
    if (windows == null) return ('Checking availability…', PillTone.neutral);
    if (windows.isEmpty) return ('Fully booked', PillTone.neutral);
    final now = facultyNow();
    final (start, end) = windows.first;
    if (dayKey(now) == dayKey(_date)) {
      // Today, what matters is when you can walk in.
      return (
        start <= now.hour * 60 + now.minute + 1
            ? 'Free now until ${timeLabel(end)}'
            : 'Free from ${timeLabel(start)}',
        PillTone.success,
      );
    }
    final free = windows.fold(0, (sum, w) => sum + w.$2 - w.$1);
    const openMinutes = BookingTime.openingMinutes;
    return (
      free == openMinutes
          ? 'Free all day'
          : '${BookingTime.durationLabel(free)} free',
      PillTone.success,
    );
  }
}

class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    required this.date,
    required this.intervals,
    required this.status,
    required this.onTap,
  });
  final Room room;
  final String date;

  /// Reserved intervals for [date], or null while unknown.
  final List<BusyInterval>? intervals;
  final (String, PillTone) status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: RoomArtwork(room: room, width: 88, height: 88),
            ),
            const SizedBox(width: AppSpace.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      roomTypeLabel(room),
                      if (room.floor != null) 'Floor ${room.floor}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: AppSpace.sm + 2),
                  StatusPill(
                    status.$1,
                    tone: status.$2,
                    icon: status.$2 == PillTone.success
                        ? Icons.check_circle_rounded
                        : room.bookingEnabled
                        ? null
                        : Icons.info_outline_rounded,
                  ),
                  if (room.bookingEnabled && intervals != null) ...[
                    const SizedBox(height: AppSpace.sm + 2),
                    DayAvailabilityBar(date: date, intervals: intervals!),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: AppSpace.xs, top: 2),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin whole-day bar: morning and afternoon separated by the lunch gap.
class DayAvailabilityBar extends StatelessWidget {
  const DayAvailabilityBar({
    super.key,
    required this.date,
    required this.intervals,
  });
  final String date;
  final List<BusyInterval> intervals;
  @override
  Widget build(BuildContext context) {
    Widget session(int start, int end) => Expanded(
      flex: end - start,
      child: AvailabilityBar(
        date: date,
        start: start,
        end: end,
        intervals: intervals,
        height: 6,
        dividers: false,
      ),
    );
    return ExcludeSemantics(
      child: Row(
        children: [
          session(BookingTime.morningStart, BookingTime.morningEnd),
          const SizedBox(width: 4),
          session(BookingTime.afternoonStart, BookingTime.afternoonEnd),
        ],
      ),
    );
  }
}

class _RoomListSkeleton extends StatelessWidget {
  const _RoomListSkeleton();
  @override
  Widget build(BuildContext context) {
    Widget block(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      sliver: SliverList.list(
        children: [
          Semantics(
            label: 'Loading rooms',
            child: Column(
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Row(
                        children: [
                          block(88, 88),
                          const SizedBox(width: AppSpace.md + 2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                block(140, 16),
                                const SizedBox(height: AppSpace.sm),
                                block(96, 12),
                                const SizedBox(height: AppSpace.md),
                                block(120, 22),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
