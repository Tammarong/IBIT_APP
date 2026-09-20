import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/firebase_config.dart';
import '../../widgets/common.dart';
import '../../widgets/itd_brand.dart';
import '../auth/auth_controller.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.auth});
  final AuthController auth;
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final user = auth.currentUser;
        final name = (user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!
            : 'IBIT member';
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
          children: [
            const ItdBrand(section: 'Account', logoHeight: 42),
            const SizedBox(height: 26),
            const Eyebrow('Part of something good'),
            const SizedBox(height: 10),
            Text(
              'Your IBIT account.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.successTint,
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: AppColors.available,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.email ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 16,
                        color: AppColors.available,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Verified member',
                          style: TextStyle(
                            color: AppColors.available,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Eyebrow('A few things to know'),
            const SizedBox(height: 14),
            const Notice(
              'Our spaces are open Monday–Friday, 8 AM–12 PM and 1–4 PM. All times shown are Bangkok time.',
            ),
            const SizedBox(height: 12),
            const Notice(
              'Plans changed? Cancel before your reservation starts to make room for someone else.',
              icon: Icons.favorite_border_rounded,
            ),
            if (EmulatorConfig.enabled) ...[
              const SizedBox(height: 20),
              const Notice(
                'Local development build. Reservations and accounts are stored in the Firebase emulators on your computer.',
                icon: Icons.science_outlined,
              ),
            ],
            if (auth.error != null) ...[
              const SizedBox(height: 16),
              Notice(auth.error!, isError: true),
            ],
            const SizedBox(height: 26),
            OutlinedButton.icon(
              key: const Key('sign_out'),
              onPressed: auth.loading ? null : auth.signOut,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                'IBIT ROOMS  /  VERSION 1.0',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.7,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
