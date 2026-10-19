import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart';
import '../widgets/backgrounds.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/page_routes.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'validators.dart';

@visibleForTesting
String completeRegistrationFirebaseErrorMessage(FirebaseException error, S s) {
  return switch (error.code) {
    'network-request-failed' ||
    'unavailable' ||
    'deadline-exceeded' => s.errNetwork,
    _ => s.errProfileCreate,
  };
}

// Complete registration when the user has no Firestore profile.
class CompleteRegistrationScreen extends StatefulWidget {
  const CompleteRegistrationScreen({super.key, required this.email});

  final String email;

  @override
  State<CompleteRegistrationScreen> createState() =>
      _CompleteRegistrationScreenState();
}

class _CompleteRegistrationScreenState
    extends State<CompleteRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _authService = AuthService();
  final _userService = UserService();
  final _username = TextEditingController();

  // Track the registration loading state.
  bool _loading = false;

  // Clear the username controller when the screen closes.
  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  // Complete registration by creating the user's Firestore profile.
  Future<void> _complete() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    // Check that the username is valid.
    if (!(_form.currentState?.validate() ?? false)) return;

    final username = _username.text.trim();
    final s = S.of(context);

    // Show loading while completing registration.
    setState(() => _loading = true);

    try {
      // Make sure the user's email is still verified.
      if (!await _authService.isEmailVerified()) {
        await _returnToLogin();
        return;
      }

      // Create the missing profile and reserve the username.
      await _userService.createCurrentUserProfile(username: username);

      if (!mounted) return;

      // Open Home after completing registration.
      Navigator.of(context).pushAndRemoveUntil(
        riseRoute(HomeScreen(username: username)),
        (_) => false,
      );

    } on UsernameAlreadyTakenException {
      // Show an error if another user owns the username.
      if (!mounted) return;
      _showError(s.errUsernameTaken);

    } on UserProfileConflictException {
      // Show an error if the profile data conflicts.
      if (!mounted) return;
      _showError(s.errProfileConflict);

    } on FirebaseException catch (error) {
      // Show a network or profile creation error.
      if (!mounted) return;
      _showError(completeRegistrationFirebaseErrorMessage(error, s));

    } on StateError {
      // Show an error if the authentication session is invalid.
      if (!mounted) return;
      _showError(s.errAuthSessionMismatch);

    } catch (_) {
      // Handle unexpected registration errors.
      if (!mounted) return;
      _showError(s.errAuthGeneral);

    } finally {
      // Stop loading after the process finishes.
      if (mounted) setState(() => _loading = false);
    }
  }

  // Cancel registration and return to Login.
  Future<void> _cancel() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await _returnToLogin();

    } catch (_) {
      // Show an error if signing out fails.
      if (!mounted) return;
      _showError(S.of(context).errLogout);

    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Sign out and navigate back to the Login screen.
  Future<void> _returnToLogin() async {
    await _authService.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      riseRoute(LoginScreen(email: widget.email)),
      (_) => false,
    );
  }

  // Show an error message to the user.
  void _showError(String message) {
    showEthmarToast(context, message, type: EthmarToastType.error);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return PopScope(
      canPop: false,

      // Handle the back button by canceling registration.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },

      child: Scaffold(
        body: LeafPrintBackground(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Registration completion header.
                AuthHeader(
                  title: s.completeRegistrationTitle,
                  accent: s.completeRegistrationAccent,
                  character: 'ethmar_buddy_seedling',
                ),

                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    24,
                    28,
                    24,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Entrance(
                    delay: const Duration(milliseconds: 150),
                    child: Form(
                      key: _form,
                      child: Column(
                        children: [
                          // Explain why registration must be completed.
                          Text(
                            s.completeRegistrationBody,
                            textAlign: TextAlign.center,
                            style: AppText.body(context),
                          ),

                          const SizedBox(height: 24),

                          // Let the user choose a username.
                          EthmarTextField(
                            label: s.username,
                            hint: s.usernameHint,
                            enabled: !_loading,
                            controller: _username,
                            forceLtr: true,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newUsername],
                            validator: (value) => Validators.username(value, s),
                            onSubmitted: _loading ? null : (_) => _complete(),
                          ),

                          const SizedBox(height: 28),

                          // Button to finish creating the profile.
                          EthmarButton(
                            label: s.completeRegistrationButton,
                            showArrow: true,
                            loading: _loading,
                            onPressed: _loading ? null : _complete,
                          ),

                          const SizedBox(height: 12),

                          // Button to cancel and return to Login.
                          EthmarButton(
                            label: s.cancel,
                            outlined: true,
                            onPressed: _loading ? null : _cancel,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
