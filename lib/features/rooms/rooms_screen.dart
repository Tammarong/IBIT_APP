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

  String _availabilityLabel(List<BusyInterval> busy) {
    final now = facultyNow();
    final today = dayKey(now) == dayKey(_date);
    final lower = today ? now.hour * 60 + now.minute + 1 : 0;
    final sorted = [...busy]
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    for (final session in const [
      (BookingTime.morningStart, BookingTime.morningEnd),
      (BookingTime.afternoonStart, BookingTime.afternoonEnd),
    ]) {
      var start = session.$1 < lower ? lower : session.$1;
      if (start >= session.$2) continue;
      for (final interval in sorted.where(
        (value) =>
            value.endMinute > session.$1 && value.startMinute < session.$2,
      )) {
        if (interval.endMinute <= start) continue;
        if (interval.startMinute > start) {
          return '${today && start <= lower ? 'Available now' : 'Available ${timeLabel(start)}'}–${timeLabel(interval.startMinute)}';
        }
        start = interval.endMinute > start ? interval.endMinute : start;
      }
      if (start < session.$2) {
        return '${today && start <= lower ? 'Available now' : 'Available ${timeLabel(start)}'}–${timeLabel(session.$2)}';
      }
    }
    return 'Fully booked';
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ItdBrand(
                  section: 'IBIT Room Reservations',
                  logoHeight: 38,
                ),
                const SizedBox(height: 22),
                Text(
                  'Find your room',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose a date, then find the space that fits your day.',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 22),
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
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search rooms or facilities',
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
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...[
                        ('all', 'All rooms'),
                        ('classroom', 'Classrooms'),
                        ('computer', 'Computer rooms'),
                        ('other', 'Other'),
                      ].map(
                        (option) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(option.$2),
                            selected: _category == option.$1,
                            onSelected: (_) =>
                                setState(() => _category = option.$1),
                          ),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Available only'),
                        selected: _availableOnly,
                        onSelected: (value) =>
                            setState(() => _availableOnly = value),
                        showCheckmark: false,
                        avatar: Icon(
                          _availableOnly ? Icons.check : Icons.tune,
                          size: 18,
                        ),
                      ),
                    ],
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
                final query = _search.text.trim().toLowerCase();
                final rooms = roomSnapshot.data!
                    .where(
                      (r) =>
                          r.listed &&
                          (query.isEmpty ||
                              r.name.toLowerCase().contains(query) ||
                              r.subtitle.toLowerCase().contains(query) ||
                              (r.officialName ?? '').toLowerCase().contains(
                                query,
                              ) ||
                              r.facilities.any(
                                (value) => value.toLowerCase().contains(query),
                              )) &&
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${rooms.length} ${rooms.length == 1 ? 'room' : 'rooms'} found',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('EEE, d MMM').format(_date),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                        title: !snapshot.hasData
                            ? 'Checking availability'
                            : query.isNotEmpty ||
                                  _category != 'all' ||
                                  _availableOnly
                            ? 'No matching rooms'
                            : 'A full day of good ideas',
                        message: !snapshot.hasData
                            ? 'Waiting for the latest room schedules.'
                            : query.isNotEmpty ||
                                  _category != 'all' ||
                                  _availableOnly
                            ? 'Try a different search, category, or availability filter.'
                            : 'All rooms are booked for this date. Choose another weekday.',
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
                                    ? (EmulatorConfig.bookingsAvailable
                                          ? 'Booking setup pending'
                                          : 'Booking coming soon')
                                    : 'Information only')
                              : !snapshot.hasData || snapshot.hasError
                              ? 'Checking availability'
                              : free
                              ? _availabilityLabel(
                                  snapshot.data?[room.id] ?? [],
                                )
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
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 28),
                      child: Text(
                        EmulatorConfig.bookingsAvailable
                            ? 'Room names and photos: official ITD website.\nApp bookings: Monday–Friday · 8 AM–12 PM & 1–4 PM · Bangkok time'
                            : 'Room names and photos: official ITD website.\nOnline booking is being prepared.',
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
  Widget build(BuildContext context) {
    final type = switch (room.category) {
      'computer' => 'Computer room',
      'classroom' => 'Classroom',
      _ => 'Specialized room',
    };
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 112, child: RoomArtwork(room: room, height: 142)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        room.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        [
                          type,
                          if (room.floor != null) 'Floor ${room.floor}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        label: availability,
                        child: Row(
                          children: [
                            Icon(
                              available
                                  ? Icons.check_circle_rounded
                                  : Icons.info_outline_rounded,
                              size: 16,
                              color: available
                                  ? AppColors.available
                                  : AppColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                availability,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  color: available
                                      ? AppColors.available
                                      : AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
