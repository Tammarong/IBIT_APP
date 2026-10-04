import 'package:flutter/material.dart';
import '../../core/firebase_config.dart';
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

  void _setDate(DateTime date) => setState(() {
    _date = dateOnly(date);
    _availability = widget.rooms.watchAvailability(dayKey(_date));
  });

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Room details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.xs,
          AppSpace.gutter,
          AppSpace.xl,
        ),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: RoomArtwork(room: room, height: 220),
          ),
          const SizedBox(height: AppSpace.lg + 4),
          Text(room.name, style: text.headlineMedium),
          if (room.officialName != null) ...[
            const SizedBox(height: 2),
            Text(
              room.officialName!,
              style: text.bodyLarge!.copyWith(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              StatusPill(
                roomTypeLabel(room),
                tone: PillTone.navy,
                icon: room.category == 'computer'
                    ? Icons.computer_rounded
                    : Icons.meeting_room_outlined,
              ),
              if (room.floor != null)
                StatusPill('Floor ${room.floor}', icon: Icons.stairs_outlined),
              room.bookingEnabled
                  ? const StatusPill(
                      'Bookable',
                      tone: PillTone.success,
                      icon: Icons.event_available_rounded,
                    )
                  : const StatusPill(
                      'View only',
                      icon: Icons.visibility_outlined,
                    ),
            ],
          ),
          if (room.description.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            Text(
              room.description,
              style: text.bodyMedium!.copyWith(color: AppColors.muted),
            ),
          ],
          if (room.facilities.isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            Text('Facilities', style: text.titleSmall),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [for (final f in room.facilities) StatusPill(f)],
            ),
          ],
          if (room.sourceUrl != null) ...[
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Official ITD room listing · itd.kmutnb.ac.th',
                    style: text.bodySmall!.copyWith(color: AppColors.accent),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.xl),
          if (!room.bookingEnabled)
            Notice(
              room.category == 'classroom' || room.category == 'computer'
                  ? (EmulatorConfig.bookingsAvailable
                        ? 'This room is listed by ITD. App booking will become available after its Firebase record is configured.'
                        : 'Rooms and sign-in use live Firebase. Online booking is being prepared.')
                  : 'This specialized room is listed for information only and cannot be booked in the app.',
            )
          else ...[
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    'Availability',
                    subtitle: 'Bangkok time · Monday to Friday',
                  ),
                  const SizedBox(height: AppSpace.lg),
                  DayStepper(date: _date, onChanged: _setDate),
                  const SizedBox(height: AppSpace.lg + 4),
                  StreamBuilder<Map<String, List<BusyInterval>>>(
                    key: ValueKey(dayKey(_date)),
                    stream: _availability,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Notice(
                          'Availability couldn’t be loaded. Check your connection and try again.',
                          isError: true,
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpace.xl),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return AvailabilityTimeline(
                        intervals: snapshot.data![room.id] ?? [],
                        date: dayKey(_date),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            const Notice(
              'Choose any start and end time within one session. You can cancel until your booking starts.',
              tone: NoticeTone.accent,
            ),
          ],
        ],
      ),
      bottomNavigationBar: !room.bookingEnabled
          ? null
          : DecoratedBox(
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
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReservationScreen(
                          room: room,
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
            ),
    );
  }
}
