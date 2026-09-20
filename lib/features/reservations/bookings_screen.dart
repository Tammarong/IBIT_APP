import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/firebase_config.dart';
import '../../core/theme.dart';
import '../../core/booking_time.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/itd_brand.dart';

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
  int _filter = 0;
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

  Future<void> _cancel(Reservation booking) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Release this room?'),
        content: const Text(
          'Your reservation will be cancelled and the time will become available to the IBIT community.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (answer != true || !mounted) return;
    setState(() => _cancelling.add(booking.id));
    try {
      await widget.reservations.cancelReservation(booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reservation cancelled. The room is available again.',
            ),
          ),
        );
      }
    } on ReservationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not cancel. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling.remove(booking.id));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ItdBrand(section: 'My Bookings', logoHeight: 42),
                const SizedBox(height: 26),
                const Eyebrow('A little planning. A lot of possibility.'),
                const SizedBox(height: 10),
                Text(
                  'Your spaces,\nall in one place.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Upcoming', 'Completed', 'Cancelled']
                      .asMap()
                      .entries
                      .map(
                        (entry) => ChoiceChip(
                          label: Text(entry.value),
                          selected: _filter == entry.key,
                          showCheckmark: false,
                          selectedColor: AppColors.mint,
                          side: const BorderSide(color: AppColors.line),
                          onSelected: (_) =>
                              setState(() => _filter = entry.key),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        StreamBuilder<List<Room>>(
          stream: _rooms,
          builder: (context, roomSnapshot) => StreamBuilder<List<Reservation>>(
            stream: _bookings,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: EmptyState(
                    title: 'Your bookings couldn’t load',
                    message: 'Check your connection and try again.',
                    icon: Icons.wifi_off_rounded,
                    action: OutlinedButton(
                      onPressed: () => setState(
                        () => _bookings = widget.reservations
                            .watchMyReservations(widget.uid),
                      ),
                      child: const Text('Try again'),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final bookings = snapshot.data!
                  .where(
                    (b) => switch (_filter) {
                      2 => b.isCancelled,
                      1 => !b.isCancelled && BookingTime.hasEnded(b),
                      _ => !b.isCancelled && !BookingTime.hasEnded(b),
                    },
                  )
                  .toList();
              bookings.sort(
                (a, b) =>
                    '${a.date}${a.startMinute.toString().padLeft(4, '0')}'
                        .compareTo(
                          '${b.date}${b.startMinute.toString().padLeft(4, '0')}',
                        ) *
                    (_filter == 0 ? 1 : -1),
              );
              if (bookings.isEmpty) {
                return SliverToBoxAdapter(
                  child: EmptyState(
                    title: switch (_filter) {
                      1 => 'Good things are ahead',
                      2 => 'Nothing cancelled',
                      _ =>
                        EmulatorConfig.bookingsAvailable
                            ? 'Your next idea starts here'
                            : 'Online booking is being prepared',
                    },
                    message: switch (_filter) {
                      1 => 'Your completed reservations will appear here.',
                      2 =>
                        'Cancelled reservations will stay here for your reference.',
                      _ =>
                        EmulatorConfig.bookingsAvailable
                            ? 'Find a room and make a little time for something great.'
                            : 'You can browse live ITD room information now. Reservations will appear here when booking opens.',
                    },
                    action: _filter == 0
                        ? FilledButton(
                            onPressed: widget.onExplore,
                            child: const Text('Find a room'),
                          )
                        : null,
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                sliver: SliverList.separated(
                  itemCount: bookings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    Room? room;
                    for (final r in roomSnapshot.data ?? <Room>[]) {
                      if (r.id == booking.roomId) room = r;
                    }
                    final started = BookingTime.hasStarted(booking),
                        ended = BookingTime.hasEnded(booking);
                    final status = booking.isCancelled
                        ? 'Cancelled'
                        : ended
                        ? 'Completed'
                        : started
                        ? 'In progress'
                        : 'Confirmed';
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (room != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 64,
                                    child: RoomArtwork(room: room, height: 64),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      room?.name ?? booking.roomId,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      status,
                                      style: TextStyle(
                                        color: booking.isCancelled
                                            ? AppColors.muted
                                            : AppColors.accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          DetailLine('Date', dateLabel(booking.date)),
                          DetailLine(
                            'Time',
                            '${timeLabel(booking.startMinute)} – ${timeLabel(booking.endMinute)}',
                          ),
                          DetailLine('Purpose', booking.purpose),
                          DetailLine('Reference', booking.reference),
                          if (!booking.isCancelled && !started) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _cancelling.contains(booking.id)
                                    ? null
                                    : () => _cancel(booking),
                                child: _cancelling.contains(booking.id)
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Cancel reservation'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
