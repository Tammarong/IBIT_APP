import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/itd_brand.dart';
import '../auth/auth_controller.dart';
import 'profile_image_repository.dart';

typedef ProfileImagePicker = Future<ProfileImageSelection?> Function();

class ProfileImageSelection {
  const ProfileImageSelection({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.auth,
    this.imageRepository,
    this.pickImage,
  });

  final AuthController auth;
  final ProfileImageRepository? imageRepository;
  final ProfileImagePicker? pickImage;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final ProfileImageRepository _images =
      widget.imageRepository ?? FirebaseProfileImageRepository();

  Future<ProfileImageSelection?> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 82,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final lower = file.path.toLowerCase();
    final contentType =
        file.mimeType ??
        (lower.endsWith('.png')
            ? 'image/png'
            : lower.endsWith('.webp')
            ? 'image/webp'
            : lower.endsWith('.heic') || lower.endsWith('.heif')
            ? 'image/heic'
            : 'image/jpeg');
    return ProfileImageSelection(
      bytes: await file.readAsBytes(),
      contentType: contentType,
    );
  }

  Future<void> _editProfile() async {
    widget.auth.clearError();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditProfileSheet(
        auth: widget.auth,
        images: _images,
        pickImage: widget.pickImage ?? _pickFromGallery,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: widget.auth,
        builder: (context, _) {
          final user = widget.auth.currentUser;
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        ProfileAvatar(
                          name: name,
                          photoUrl: user?.photoURL,
                          radius: 32,
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
                    const SizedBox(height: AppSpace.md),
                    const Divider(),
                    const SizedBox(height: AppSpace.xs),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        key: const Key('edit_profile'),
                        onPressed: widget.auth.loading ? null : _editProfile,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit profile'),
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
              if (widget.auth.error != null) ...[
                const SizedBox(height: AppSpace.lg),
                Notice(widget.auth.error!, isError: true),
              ],
              const SizedBox(height: AppSpace.xl),
              OutlinedButton.icon(
                key: const Key('sign_out'),
                onPressed: widget.auth.loading ? null : widget.auth.signOut,
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

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.bytes,
    this.radius = 32,
  });

  final String name;
  final String? photoUrl;
  final Uint8List? bytes;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.navyTint,
      child: Center(
        child: Text(
          name.trim().isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
    Widget image;
    if (bytes != null) {
      image = Image.memory(
        bytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (photoUrl != null && photoUrl!.isNotEmpty) {
      image = Image.network(
        photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      image = fallback;
    }
    return Semantics(
      image: true,
      label: 'Profile picture for $name',
      child: ClipOval(
        child: SizedBox.square(dimension: radius * 2, child: image),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.auth,
    required this.images,
    required this.pickImage,
  });

  final AuthController auth;
  final ProfileImageRepository images;
  final ProfileImagePicker pickImage;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  ProfileImageSelection? _selection;
  bool _saving = false;
  bool _picking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.auth.currentUser?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    if (_saving || _picking) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final selection = await widget.pickImage();
      if (selection != null && mounted) {
        if (selection.bytes.lengthInBytes > 5 * 1024 * 1024) {
          setState(
            () => _error =
                'The selected image is too large. Choose an image under 5 MB.',
          );
        } else {
          setState(() => _selection = selection);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The photo library could not open. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    final user = widget.auth.currentUser;
    if (user == null) {
      setState(() => _error = 'Sign in again before updating your profile.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String? photoUrl;
      if (_selection != null) {
        photoUrl = await widget.images.uploadProfileImage(
          userId: user.uid,
          bytes: _selection!.bytes,
          contentType: _selection!.contentType,
        );
      }
      final updated = await widget.auth.updateProfile(
        displayName: _name.text.trim(),
        photoUrl: photoUrl,
      );
      if (updated && mounted) {
        Navigator.pop(context, true);
      } else if (mounted && widget.auth.currentUser == null) {
        Navigator.pop(context);
      }
    } on ProfileImageException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.currentUser;
    final displayName = _name.text.trim().isEmpty
        ? 'IBIT member'
        : _name.text.trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.sm,
        AppSpace.gutter,
        MediaQuery.viewInsetsOf(context).bottom + AppSpace.xl,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit profile',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'Update how your name and photo appear in IBIT Rooms.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpace.xl),
              Center(
                child: ProfileAvatar(
                  name: displayName,
                  photoUrl: user?.photoURL,
                  bytes: _selection?.bytes,
                  radius: 48,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Center(
                child: OutlinedButton.icon(
                  key: const Key('choose_profile_photo'),
                  onPressed: _saving || _picking ? null : _choosePhoto,
                  icon: _picking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined, size: 19),
                  label: Text(
                    _selection == null ? 'Choose photo' : 'Choose another',
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              TextFormField(
                key: const Key('profile_name'),
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => _save(),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a display name.'
                    : value.trim().length < 2
                    ? 'Use at least 2 characters.'
                    : null,
              ),
              if (_error != null || widget.auth.error != null) ...[
                const SizedBox(height: AppSpace.md),
                Notice(_error ?? widget.auth.error!, isError: true),
              ],
              const SizedBox(height: AppSpace.lg),
              FilledButton(
                key: const Key('save_profile'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save changes'),
              ),
              const SizedBox(height: AppSpace.sm),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
