import 'package:flutter/material.dart';

import '../../core/firebase_config.dart';
import '../../core/theme.dart';
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
                        const SizedBox(height: 16),
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
                          const SizedBox(height: 12),
                          _ErrorMessage(widget.controller.error!),
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
      return Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ItdBrand(section: 'IBIT Rooms'),
                        const SizedBox(height: 26),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 174,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  'https://www.itd.kmutnb.ac.th/img/menu-about/class-room/3A02.jpg',
                                  fit: BoxFit.cover,
                                  cacheWidth: 1200,
                                  loadingBuilder: (context, child, progress) =>
                                      progress == null
                                      ? child
                                      : Image.asset(
                                          'assets/rooms/room-01.png',
                                          fit: BoxFit.cover,
                                        ),
                                  errorBuilder: (context, error, stack) =>
                                      Image.asset(
                                        'assets/rooms/room-01.png',
                                        fit: BoxFit.cover,
                                      ),
                                ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Color(0xCC192F59),
                                      ],
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  left: 18,
                                  bottom: 16,
                                  right: 18,
                                  child: Text(
                                    'A little space.\nA world of possibilities.',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      height: 1.15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          _register
                              ? 'Make yourself at home.'
                              : 'Welcome to your space.',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            letterSpacing: -0.9,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _register
                              ? 'Create an account to reserve your next IBIT room.'
                              : 'Sign in to find a room and make time for what matters.',
                          style: const TextStyle(
                            color: AppColors.muted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_register) ...[
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
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
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          enabled: !loading,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
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
                          const SizedBox(height: 12),
                          _ErrorMessage(widget.controller.error!),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: loading ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_register ? 'Create account' : 'Sign in'),
                        ),
                        const SizedBox(height: 18),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'or',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: loading
                              ? null
                              : widget.controller.signInGoogle,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                          ),
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: Text(
                            EmulatorConfig.canSimulateGoogle
                                ? 'Try simulated Google account'
                                : 'Continue with Google',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'LOCAL DEVELOPMENT • FIREBASE EMULATORS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                                letterSpacing: 1.1,
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.cream,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ItdBrand(section: 'IBIT Rooms'),
                const SizedBox(height: 56),
                const CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.mint,
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppColors.accent,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'One last step.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Verify ${widget.controller.currentUser?.email ?? 'your email'} to start reserving rooms.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.6, color: AppColors.muted),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    EmulatorConfig.enabled
                        ? 'Open the verification link in the Firebase emulator terminal or Logs tab. Then come back here and tap “I’ve verified my email”.'
                        : 'We sent a verification link to your inbox. Check your spam folder too, then return here after opening the link.',
                    style: const TextStyle(height: 1.6),
                  ),
                ),
                if (widget.controller.error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorMessage(widget.controller.error!),
                ],
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(_message!, textAlign: TextAlign.center),
                    ),
                  ),
                const SizedBox(height: 26),
                FilledButton(
                  onPressed: widget.controller.loading
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
                    widget.controller.loading
                        ? 'Checking…'
                        : 'I’ve verified my email',
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.controller.loading
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
                TextButton(
                  onPressed: widget.controller.loading
                      ? null
                      : widget.controller.signOut,
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

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDE8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF913D31), height: 1.4),
      ),
    ),
  );
}
