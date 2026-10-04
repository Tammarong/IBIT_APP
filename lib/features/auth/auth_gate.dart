import 'package:flutter/material.dart';

import '../../core/firebase_config.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/itd_brand.dart';
import 'auth_controller.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.controller, required this.child});
  final AuthController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.initialized) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (controller.currentUser == null) {
        return AuthScreen(controller: controller);
      }
      if (!controller.currentUser!.emailVerified) {
        return _VerificationScreen(controller: controller);
      }
      return child;
    },
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});
  final AuthController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (_register) {
      await widget.controller.register(_name.text, _email.text, _password.text);
    } else {
      await widget.controller.signIn(_email.text, _password.text);
    }
  }

  Future<void> _resetPassword() async {
    final email = TextEditingController(text: _email.text);
    final form = GlobalKey<FormState>();
    var sent = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateDialog) => ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => AlertDialog(
            title: Text(sent ? 'Check your email' : 'Reset your password'),
            content: sent
                ? Text(
                    EmulatorConfig.enabled
                        ? 'Your reset link appears in the Firebase emulator terminal or Logs tab. Open the link to choose a new password.'
                        : 'If an account uses this email, a password reset link is on its way. Check your inbox and spam folder.',
                  )
                : Form(
                    key: form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Enter your account email and we’ll send a reset link.',
                        ),
                        const SizedBox(height: AppSpace.lg),
                        TextFormField(
                          controller: email,
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                          ),
                          validator: _validateEmail,
                        ),
                        if (widget.controller.error != null) ...[
                          const SizedBox(height: AppSpace.md),
                          Notice(widget.controller.error!, isError: true),
                        ],
                      ],
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: widget.controller.loading
                    ? null
                    : () => Navigator.pop(context),
                child: Text(sent ? 'Done' : 'Cancel'),
              ),
              if (!sent)
                FilledButton(
                  onPressed: widget.controller.loading
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          if (await widget.controller.resetPassword(
                                email.text,
                              ) &&
                              context.mounted) {
                            updateDialog(() => sent = true);
                          }
                        },
                  child: Text(
                    widget.controller.loading ? 'Sending…' : 'Send reset link',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    // Dialog dismissal animation may still hold its text field briefly.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    email.dispose();
    if (mounted) widget.controller.clearError();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final loading = widget.controller.loading;
      final text = Theme.of(context).textTheme;
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.lg,
              AppSpace.gutter,
              AppSpace.xxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: ItdLogo(height: 34),
                        ),
                        const SizedBox(height: AppSpace.lg + 4),
                        const _Hero(),
                        const SizedBox(height: AppSpace.xl),
                        Semantics(
                          header: true,
                          child: Text(
                            _register ? 'Create your account' : 'Welcome back',
                            style: text.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          EmulatorConfig.bookingsAvailable
                              ? (_register
                                    ? 'Use your email to start reserving IBIT rooms.'
                                    : 'Sign in to find a free room and manage your bookings.')
                              : (_register
                                    ? 'Create an account to explore ITD rooms with live Firebase.'
                                    : 'Sign in to explore ITD rooms. Online booking is being prepared.'),
                          style: text.bodyMedium!.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: AppSpace.lg + 4),
                        if (_register) ...[
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            enabled: !loading,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter your name.'
                                : null,
                          ),
                          const SizedBox(height: AppSpace.md),
                        ],
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          enabled: !loading,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: AppSpace.md),
                        TextFormField(
                          controller: _password,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            helperText: _register
                                ? 'At least 6 characters.'
                                : null,
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          autofillHints: [
                            _register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          enabled: !loading,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter your password.'
                              : _register && value.length < 6
                              ? 'Use at least 6 characters.'
                              : null,
                        ),
                        if (!_register)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: loading ? null : _resetPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        if (widget.controller.error != null) ...[
                          const SizedBox(height: AppSpace.sm),
                          Notice(widget.controller.error!, isError: true),
                        ],
                        const SizedBox(height: AppSpace.lg),
                        FilledButton(
                          onPressed: loading ? null : _submit,
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.muted,
                                  ),
                                )
                              : Text(_register ? 'Create account' : 'Sign in'),
                        ),
                        const SizedBox(height: AppSpace.lg),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.lg,
                              ),
                              child: Text(
                                'or',
                                style: text.bodySmall!.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: AppSpace.lg),
                        OutlinedButton.icon(
                          onPressed: loading
                              ? null
                              : widget.controller.signInGoogle,
                          icon: const Icon(
                            Icons.g_mobiledata_rounded,
                            size: 28,
                          ),
                          label: Text(
                            EmulatorConfig.canSimulateGoogle
                                ? 'Try simulated Google account'
                                : 'Continue with Google',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppSpace.md),
                        TextButton(
                          onPressed: loading
                              ? null
                              : () {
                                  widget.controller.clearError();
                                  setState(() => _register = !_register);
                                },
                          child: Text(
                            _register
                                ? 'Already have an account? Sign in'
                                : 'New to IBIT Rooms? Create account',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (EmulatorConfig.enabled)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.sm),
                            child: Center(
                              child: StatusPill(
                                'Local development · Firebase emulators',
                                tone: PillTone.accent,
                                icon: Icons.science_outlined,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    Widget fallback() =>
        Image.asset('assets/rooms/room-01.png', fit: BoxFit.cover);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl - 4),
      child: SizedBox(
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: Image.network(
                'https://www.itd.kmutnb.ac.th/img/menu-about/class-room/3A02.jpg',
                fit: BoxFit.cover,
                cacheWidth: 1200,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : fallback(),
                errorBuilder: (context, error, stack) => fallback(),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00192F59), Color(0xE6192F59)],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 28, height: 4, color: AppColors.orange),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'IBIT Rooms',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge!.copyWith(color: Colors.white),
                  ),
                  Text(
                    'Reserve ITD classrooms and computer rooms.',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Colors.white.withValues(alpha: .9),
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
}

String? _validateEmail(String? value) =>
    value == null ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? 'Enter a valid email address.'
    : null;

class _VerificationScreen extends StatefulWidget {
  const _VerificationScreen({required this.controller});
  final AuthController controller;
  @override
  State<_VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<_VerificationScreen> {
  String? _message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final loading = widget.controller.loading;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: ItdLogo(height: 34),
                  ),
                  const SizedBox(height: AppSpace.xxl + 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(
                        color: AppColors.navyTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        color: AppColors.ink,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      'One last step.',
                      textAlign: TextAlign.center,
                      style: text.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'Verify ${widget.controller.currentUser?.email ?? 'your email'} to start reserving rooms.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium!.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Notice(
                    EmulatorConfig.enabled
                        ? 'Open the verification link in the Firebase emulator terminal or Logs tab. Then come back here and tap “I’ve verified my email”.'
                        : 'We sent a verification link to your inbox. Check your spam folder too, then return here after opening the link.',
                    icon: Icons.mail_outline_rounded,
                  ),
                  if (widget.controller.error != null) ...[
                    const SizedBox(height: AppSpace.md),
                    Notice(widget.controller.error!, isError: true),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: AppSpace.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.xl),
                  FilledButton(
                    onPressed: loading
                        ? null
                        : () async {
                            if (await widget.controller.refreshUser() &&
                                mounted &&
                                widget.controller.currentUser?.emailVerified !=
                                    true) {
                              setState(
                                () => _message =
                                    'Your email is not verified yet. Open the link and try again.',
                              );
                            }
                          },
                    child: Text(
                      loading ? 'Checking…' : 'I’ve verified my email',
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  OutlinedButton(
                    onPressed: loading
                        ? null
                        : () async {
                            if (await widget.controller.sendVerification() &&
                                mounted) {
                              setState(
                                () => _message = EmulatorConfig.enabled
                                    ? 'A new verification link is available in the emulator logs.'
                                    : 'Verification email sent. Please check your inbox.',
                              );
                            }
                          },
                    child: const Text('Resend verification email'),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  TextButton(
                    onPressed: loading ? null : widget.controller.signOut,
                    child: const Text('Use another account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
