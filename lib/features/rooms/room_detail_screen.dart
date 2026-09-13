import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';
import '../reservations/reservation_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({
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
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late DateTime _date = widget.date;
  late Stream<Map<String, List<BusyInterval>>> _availability = widget.rooms
      .watchAvailability(dayKey(_date));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your next space', style: TextStyle(fontSize: 16)),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: RoomArtwork(room: widget.room, height: 248),
        ),
        const SizedBox(height: 26),
        const Eyebrow('IBIT faculty · Campus collection'),
        const SizedBox(height: 8),
        Text(
          widget.room.name,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          widget.room.subtitle,
          style: const TextStyle(color: AppColors.teal, fontSize: 16),
        ),
        const SizedBox(height: 20),
        Text(
          widget.room.description,
          style: const TextStyle(color: AppColors.muted, height: 1.7),
        ),
        if (widget.room.facilities.isNotEmpty) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.room.facilities
                .map(
                  (f) => Chip(
                    label: Text(f),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.line),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Make time for good ideas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final date = await pickBookingDate(context, _date);
            if (date != null) {
              setState(() {
                _date = dateOnly(date);
                _availability = widget.rooms.watchAvailability(dayKey(date));
              });
            }
          },
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(dateLabel(dayKey(_date))),
        ),
        const SizedBox(height: 24),
        StreamBuilder<Map<String, List<BusyInterval>>>(
          key: ValueKey(dayKey(_date)),
          stream: _availability,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Notice(
                'Availability could not be loaded. Please check your connection.',
                isError: true,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return AvailabilityTimeline(
              intervals: snapshot.data![widget.room.id] ?? [],
              date: dayKey(_date),
            );
          },
        ),
        const SizedBox(height: 26),
        const Notice(
          'Choose your own start and end time. Each reservation must fit within the morning or afternoon session.',
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
        child: FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReservationScreen(
                room: widget.room,
                date: _date,
                rooms: widget.rooms,
                reservations: widget.reservations,
                onBooked: widget.onBooked,
              ),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Reserve this room'),
        ),
      ),
    ),
  );
}
