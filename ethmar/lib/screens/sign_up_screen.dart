import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../widgets/auth_header.dart';
import '../widgets/backgrounds.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/page_routes.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'validators.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _authService = AuthService();
  final _userService = UserService();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _verificationAccountId;
  String? _verificationAccountEmail;
  bool _verificationSent = false;

  bool get _hasVerificationAccount =>
      _verificationAccountId != null && _verificationAccountEmail != null;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _currentUserMatchesVerificationAccount() {
    final user = FirebaseAuth.instance.currentUser;
    final accountId = _verificationAccountId;
    final accountEmail = _verificationAccountEmail;
    if (user == null || accountId == null || accountEmail == null) {
      return false;
    }

    return user.uid == accountId &&
        user.email?.trim().toLowerCase() == accountEmail.toLowerCase();
  }

  String _authErrorMessage(FirebaseAuthException error, S s) {
    return switch (error.code) {
      'invalid-email' => s.errEmailInvalid,
      'weak-password' => s.errPasswordWeak,
      'email-already-in-use' => s.errEmailAlreadyInUse,
      'too-many-requests' => s.errTooManyRequests,
      'network-request-failed' => s.errNetwork,
      _ => s.errAuthGeneral,
    };
  }

  String _firestoreErrorMessage(FirebaseException error, S s) {
    return switch (error.code) {
      'unavailable' || 'deadline-exceeded' => s.errNetwork,
      _ => s.errProfileCreate,
    };
  }

  void _showError(String message) {
    showEthmarToast(context, message, icon: Icons.error_outline_rounded);
  }

  /// Create account: creates the Firebase account (first tap only), sends
  /// the verification email, then waits in a dialog until the link is
  /// opened. Once verified, the profile is created and Home opens.
  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;

    final email = _email.text.trim();
    final password = _password.text;
    final username = _username.text.trim();
    final s = S.of(context);

    setState(() => _loading = true);
    try {
      final existingAccountEmail = _verificationAccountEmail;
      if (existingAccountEmail == null) {
        final credential = await _authService.createAccount(
          email: email,
          password: password,
        );
        final createdUser = credential.user;
        final createdEmail = createdUser?.email?.trim();
        if (createdUser == null ||
            createdEmail == null ||
            createdEmail.isEmpty) {
          throw StateError('Firebase did not return the created account.');
        }
        if (!mounted) return;
        setState(() {
          _verificationAccountId = createdUser.uid;
          _verificationAccountEmail = createdEmail;
        });
      } else if (email.toLowerCase() != existingAccountEmail.toLowerCase()) {
        _showError(s.errAuthSessionMismatch);
        return;
      }

      if (!_currentUserMatchesVerificationAccount()) {
        _showError(s.errAuthSessionMismatch);
        return;
      }

      // Skipped when an earlier attempt already got verified (e.g. the
      // username was taken and the user picked a new one).
      if (!await _authService.isEmailVerified()) {
        // Send automatically only once; the dialog has a resend button.
        if (!_verificationSent) {
          await _authService.sendEmailVerification();
          _verificationSent = true;
        }
        if (!mounted) return;
        final verified = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _VerifyEmailDialog(
            email: _verificationAccountEmail ?? email,
            authService: _authService,
          ),
        );
        if (verified != true || !mounted) return;
      }

      if (!_currentUserMatchesVerificationAccount()) {
        _showError(s.errAuthSessionMismatch);
        return;
      }

      await _userService.createCurrentUserProfile(username: username);
      if (!mounted) return;
      if (!_currentUserMatchesVerificationAccount()) {
        _showError(s.errAuthSessionMismatch);
        return;
      }

      showEthmarToast(context, s.accountCreated);
      Navigator.of(context).pushAndRemoveUntil(
        riseRoute(HomeScreen(username: username)),
        (_) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showError(_authErrorMessage(error, s));
    } on UsernameAlreadyTakenException {
      if (!mounted) return;
      _showError(s.errUsernameTaken);
    } on UserProfileConflictException {
      if (!mounted) return;
      _showError(s.errProfileConflict);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showError(_firestoreErrorMessage(error, s));
    } on StateError {
      if (!mounted) return;
      _showError(s.errAuthSessionMismatch);
    } catch (_) {
      if (!mounted) return;
      _showError(s.errAuthGeneral);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: LeafPrintBackground(
        child: SingleChildScrollView(
          child: Column(
            children: [
              AuthHeader(
                title: s.signUpTitle,
                accent: s.signUpAccent,
                character: 'ethmar_buddy_seedling',
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  24,
                  36,
                  24,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Entrance(
                  delay: const Duration(milliseconds: 150),
                  child: Form(
                    key: _form,
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          EthmarTextField(
                            label: s.username,
                            hint: s.usernameHint,
                            enabled: !_loading,
                            controller: _username,
                            forceLtr: true,
                            keyboardType: TextInputType.text,
                            autofillHints: const [AutofillHints.newUsername],
                            validator: (v) => Validators.username(v, s),
                          ),
                          const SizedBox(height: 20),
                          EthmarTextField(
                            label: s.email,
                            hint: s.emailHint,
                            enabled: !_loading && !_hasVerificationAccount,
                            controller: _email,
                            forceLtr: true,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            validator: (v) => Validators.email(v, s),
                          ),
                          const SizedBox(height: 20),
                          EthmarTextField(
                            label: s.password,
                            hint: s.passwordHint,
                            enabled: !_loading && !_hasVerificationAccount,
                            controller: _password,
                            isPassword: true,
                            forceLtr: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (v) => Validators.password(v, s),
                            onSubmitted: _loading ? null : (_) => _submit(),
                          ),
                          const SizedBox(height: 36),
                          EthmarButton(
                            label: s.createButton,
                            showArrow: true,
                            loading: _loading,
                            onPressed: _loading ? null : _submit,
                          ),
                          const SizedBox(height: 12),
                          IgnorePointer(
                            ignoring: _loading,
                            child: AuthFooter(
                              question: s.alreadyHaveAccount,
                              action: s.logInLink,
                              onTap: () {
                                if (_loading) return;
                                Navigator.of(context).pushReplacement(
                                  riseRoute(const LoginScreen()),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Check your email" popup shown after the verification link is sent.
/// Checks every few seconds and closes with `true` as soon as the email is
/// verified, so sign-up can carry on to Home by itself.
class _VerifyEmailDialog extends StatefulWidget {
  const _VerifyEmailDialog({required this.email, required this.authService});

  final String email;
  final AuthService authService;

  @override
  State<_VerifyEmailDialog> createState() => _VerifyEmailDialogState();
}

class _VerifyEmailDialogState extends State<_VerifyEmailDialog>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false;
  bool _resending = false;
  String? _resendMessage;
  bool _resendFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Check right away when the user comes back from their mail app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final verified = await widget.authService.isEmailVerified();
      if (verified && mounted) {
        _timer?.cancel();
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      // Network hiccup: the next tick tries again.
    } finally {
      _checking = false;
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    final s = S.of(context);
    setState(() => _resending = true);
    String message;
    var failed = false;
    try {
      await widget.authService.sendEmailVerification();
      message = s.verificationResent;
    } on FirebaseAuthException catch (error) {
      failed = true;
      message = switch (error.code) {
        'too-many-requests' => s.errTooManyRequests,
        'network-request-failed' => s.errNetwork,
        _ => s.errAuthGeneral,
      };
    } catch (_) {
      failed = true;
      message = s.errAuthGeneral;
    }
    if (!mounted) return;
    setState(() {
      _resending = false;
      _resendMessage = message;
      _resendFailed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_unread_rounded,
                size: 56, color: AppColors.forest),
            const SizedBox(height: 16),
            Text(
              s.verifyDialogTitle,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 12),
            Text(
              s.verifyDialogBody(widget.email),
              textAlign: TextAlign.center,
              style: AppText.body(context),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: AppColors.forest),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(s.verifyDialogWaiting,
                      style: AppText.small(context,
                          color: AppColors.textSecondary)),
                ),
              ],
            ),
            if (_resendMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _resendMessage!,
                textAlign: TextAlign.center,
                style: AppText.small(context,
                    color:
                        _resendFailed ? AppColors.error : AppColors.success),
              ),
            ],
            const SizedBox(height: 24),
            EthmarButton(
              label: s.resendEmail,
              loading: _resending,
              onPressed: _resend,
            ),
            const SizedBox(height: 12),
            EthmarButton(
              label: s.cancel,
              outlined: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
