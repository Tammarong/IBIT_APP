import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'data/repositories.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_gate.dart';
import 'features/rooms/rooms_screen.dart';
import 'features/reservations/bookings_screen.dart';
import 'features/account/account_screen.dart';

class IbitApp extends StatefulWidget {
  const IbitApp({super.key});
  @override
  State<IbitApp> createState() => _IbitAppState();
}

class _IbitAppState extends State<IbitApp> {
  late final _auth = AuthController();
  late final _rooms = FirebaseRoomRepository();
  late final _reservations = FirebaseReservationRepository();
  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'IBIT Rooms',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: AuthGate(
      controller: _auth,
      child: ListenableBuilder(
        listenable: _auth,
        builder: (context, _) {
          final user = _auth.currentUser;
          if (user == null || !user.emailVerified) {
            return const SizedBox.shrink();
          }
          return AppShell(
            key: ValueKey(user.uid),
            auth: _auth,
            rooms: _rooms,
            reservations: _reservations,
          );
        },
      ),
    ),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.auth,
    required this.rooms,
    required this.reservations,
  });
  final AuthController auth;
  final RoomRepository rooms;
  final ReservationRepository reservations;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _tab,
      children: [
        RoomsScreen(
          rooms: widget.rooms,
          reservations: widget.reservations,
          onBooked: () => setState(() => _tab = 1),
        ),
        BookingsScreen(
          uid: widget.auth.currentUser!.uid,
          rooms: widget.rooms,
          reservations: widget.reservations,
          onExplore: () => setState(() => _tab = 0),
        ),
        AccountScreen(auth: widget.auth),
      ],
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Rooms',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'My Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    ),
  );
}
