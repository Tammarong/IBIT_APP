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
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: auth,
        builder: (context, _) {
          final user = auth.currentUser;
          final name = (user?.displayName?.trim().isNotEmpty ?? false)
              ? user!.displayName!
              : 'IBIT member';
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.lg,
              AppSpace.gutter,
              AppSpace.xxl,
            ),
            children: [
              const ScreenHeader(title: 'Account'),
              const SizedBox(height: AppSpace.lg + 4),
              SurfaceCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.navyTint,
                      child: Text(
                        name.characters.first.toUpperCase(),
                        style: text.headlineSmall,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: text.titleMedium),
                          Text(
                            user?.email ?? '',
                            style: text.bodySmall!.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          const StatusPill(
                            'Verified member',
                            tone: PillTone.success,
                            icon: Icons.verified_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              const SectionHeader('Booking rules'),
              const SizedBox(height: AppSpace.md),
              const SurfaceCard(
                child: Column(
                  children: [
                    InfoRow(
                      icon: Icons.calendar_month_outlined,
                      label: 'Open days',
                      value: 'Monday to Friday',
                    ),
                    SizedBox(height: AppSpace.lg),
                    InfoRow(
                      icon: Icons.schedule_rounded,
                      label: 'Sessions',
                      value: '8:00 AM–12:00 PM and 1:00–4:00 PM',
                    ),
                    SizedBox(height: AppSpace.lg),
                    InfoRow(
                      icon: Icons.public_rounded,
                      label: 'Time zone',
                      value: 'Bangkok time (GMT+7)',
                    ),
                    SizedBox(height: AppSpace.lg),
                    InfoRow(
                      icon: Icons.event_busy_outlined,
                      label: 'Cancellation',
                      value: 'Any time before your booking starts',
                    ),
                  ],
                ),
              ),
              if (EmulatorConfig.enabled) ...[
                const SizedBox(height: AppSpace.lg),
                const Notice(
                  'Local development build. Reservations and accounts are stored in the Firebase emulators on your computer.',
                  icon: Icons.science_outlined,
                  tone: NoticeTone.accent,
                ),
              ],
              if (auth.error != null) ...[
                const SizedBox(height: AppSpace.lg),
                Notice(auth.error!, isError: true),
              ],
              const SizedBox(height: AppSpace.xl),
              OutlinedButton.icon(
                key: const Key('sign_out'),
                onPressed: auth.loading ? null : auth.signOut,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: AppSpace.xl),
              Center(
                child: Text(
                  'IBIT Rooms · Version 1.0',
                  style: text.bodySmall!.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
