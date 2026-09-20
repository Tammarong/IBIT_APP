import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

class _RoomsScreenState extends State<RoomsScreen> with WidgetsBindingObserver {
  late DateTime _date = initialBookingDate();
  late DateTime _stripStart = _date;
  late Stream<List<Room>> _rooms = widget.rooms.watchRooms();
  late Stream<Map<String, List<BusyInterval>>> _availability = widget.rooms
      .watchAvailability(dayKey(_date));
  bool _availableOnly = false;
  String _category = 'all';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_date.isBefore(dateOnly(facultyNow()))) {
        _select(initialBookingDate());
      } else {
        setState(() {});
      }
    }
  }

  void _select(DateTime date) => setState(() {
    _date = dateOnly(date);
    if (_date.isBefore(_stripStart) ||
        _date.isAfter(_stripStart.add(const Duration(days: 9)))) {
      _stripStart = _date;
    }
    _availability = widget.rooms.watchAvailability(dayKey(_date));
  });
  void _retry() => setState(() {
    _rooms = widget.rooms.watchRooms();
    _availability = widget.rooms.watchAvailability(dayKey(_date));
  });
  bool _isAvailable(List<BusyInterval> busy) {
    final now = facultyNow();
    if (_date.isBefore(dateOnly(now))) return false;
    final lower = dayKey(now) == dayKey(_date)
        ? now.hour * 60 + now.minute + 1
        : 0;
    for (var m = 480; m < 960; m++) {
      if (m >= lower &&
          !(m >= 720 && m < 780) &&
          !busy.any((b) => m >= b.startMinute && m < b.endMinute)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ItdBrand(section: 'IBIT Room Reservations'),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ITD  /  Rooms',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 28),
                const Eyebrow('Your campus. Your space.'),
                const SizedBox(height: 10),
                Text(
                  'Good ideas need\na little room.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Find a space to focus, connect, and create.',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.meeting_room_outlined,
                          color: AppColors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'A space for every possibility',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '18 official spaces · 13 general rooms',
                              style: TextStyle(
                                color: Color(0xFFE8EAF0),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(child: Eyebrow('When are you coming?')),
                    TextButton.icon(
                      onPressed: () async {
                        final date = await pickBookingDate(context, _date);
                        if (date != null) {
                          _select(date);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined, size: 16),
                      label: Text(
                        DateFormat('MMM yyyy').format(_date),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 86 * (MediaQuery.textScalerOf(context).scale(14) / 14),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: 10,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final date = _stripStart.add(Duration(days: i));
                final selected = dayKey(date) == dayKey(_date);
                final weekend = date.weekday > 5;
                return Semantics(
                  selected: selected,
                  label: DateFormat('EEEE d MMMM').format(date),
                  child: InkWell(
                    onTap: weekend ? null : () => _select(date),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      width:
                          56 *
                          (MediaQuery.textScalerOf(context).scale(14) / 14),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accent : Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: selected ? AppColors.accent : AppColors.line,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('EEE').format(date),
                            style: TextStyle(
                              fontSize: 11,
                              color: selected
                                  ? Colors.white70
                                  : weekend
                                  ? Colors.grey.shade400
                                  : AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : weekend
                                  ? Colors.grey.shade400
                                  : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(
                  'Find your room',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ...[
                  ('all', 'All'),
                  ('classroom', 'Classrooms'),
                  ('computer', 'Computer'),
                  ('other', 'Other'),
                ].map(
                  (option) => ChoiceChip(
                    label: Text(option.$2),
                    selected: _category == option.$1,
                    onSelected: (_) => setState(() => _category = option.$1),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                FilterChip(
                  label: const Text('Available'),
                  selected: _availableOnly,
                  onSelected: (value) => setState(() => _availableOnly = value),
                  showCheckmark: false,
                  avatar: Icon(
                    _availableOnly ? Icons.check : Icons.tune,
                    size: 14,
                  ),
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
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
                  title: 'Let’s reconnect',
                  message:
                      'We couldn’t load the rooms. Check your connection and try again.',
                  icon: Icons.wifi_off_rounded,
                  action: OutlinedButton(
                    onPressed: _retry,
                    child: const Text('Try again'),
                  ),
                ),
              );
            }
            if (!roomSnapshot.hasData) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (roomSnapshot.data!.isEmpty) {
              return const SliverToBoxAdapter(
                child: EmptyState(
                  title: 'Rooms are being prepared',
                  message:
                      'Your faculty’s rooms will appear here once they are ready.',
                ),
              );
            }
            return StreamBuilder<Map<String, List<BusyInterval>>>(
              key: ValueKey(dayKey(_date)),
              stream: _availability,
              builder: (context, snapshot) {
                final rooms = roomSnapshot.data!
                    .where(
                      (r) =>
                          r.listed &&
                          (_category == 'all' ||
                              (_category == 'other'
                                  ? r.category != 'classroom' &&
                                        r.category != 'computer'
                                  : r.category == _category)) &&
                          (!_availableOnly ||
                              (r.bookingEnabled &&
                                  snapshot.hasData &&
                                  _isAvailable(snapshot.data![r.id] ?? []))),
                    )
                    .toList();
                return SliverList.list(
                  children: [
                    if (snapshot.hasError)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Notice(
                          'Availability could not be refreshed. Try again before reserving.',
                          isError: true,
                        ),
                      ),
                    if (rooms.isEmpty)
                      EmptyState(
                        title: snapshot.hasData
                            ? 'A full day of good ideas'
                            : 'Checking availability',
                        message: snapshot.hasData
                            ? 'All rooms are booked for this date. Choose another weekday or turn off the filter.'
                            : 'Waiting for the latest room schedules.',
                      ),
                    ...rooms.map((room) {
                      final free =
                          room.bookingEnabled &&
                          _isAvailable(snapshot.data?[room.id] ?? []);
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: RoomCard(
                          room: room,
                          availability: !room.bookingEnabled
                              ? (room.category == 'classroom' ||
                                        room.category == 'computer'
                                    ? 'Booking setup pending'
                                    : 'Information only')
                              : !snapshot.hasData || snapshot.hasError
                              ? 'Checking availability'
                              : free
                              ? 'Space available'
                              : 'Fully booked',
                          available:
                              snapshot.hasData && !snapshot.hasError && free,
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
                      );
                    }),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 28),
                      child: Text(
                        'Room names and photos: official ITD website.\nApp bookings: Monday–Friday · 8 AM–12 PM & 1–4 PM · Bangkok time',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                          height: 1.7,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    ),
  );
}

class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    required this.availability,
    required this.available,
    required this.onTap,
  });
  final Room room;
  final String availability;
  final bool available;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              RoomArtwork(room: room, height: 198),
              Positioned(
                left: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cream.withValues(alpha: .96),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: available
                            ? AppColors.available
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        availability,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        room.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.mint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_outward_rounded,
                    size: 21,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
