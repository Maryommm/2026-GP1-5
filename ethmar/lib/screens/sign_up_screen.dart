import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../widgets/auth_header.dart';
import '../widgets/backgrounds.dart';
import '../widgets/entrance.dart';
import '../widgets/email_verification_dialog.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/page_routes.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'validators.dart';

// Screen for creating a new user account.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _authService = AuthService();
  final _userService = UserService();

  // Store the information entered by the user.
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  // Track registration and email verification.
  bool _loading = false;
  String? _verificationAccountId;
  String? _verificationAccountEmail;
  bool _verificationSent = false;

  // Check if there is an account waiting for verification.
  bool get _hasVerificationAccount =>
      _verificationAccountId != null && _verificationAccountEmail != null;

  // Clear the text controllers when the screen closes.
  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // Check that the same user is still signed in.
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

  // Show the correct message for Firebase Auth errors.
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

  // Show the correct message for Firestore errors.
  String _firestoreErrorMessage(FirebaseException error, S s) {
    return switch (error.code) {
      'unavailable' || 'deadline-exceeded' => s.errNetwork,
      _ => s.errProfileCreate,
    };
  }

  // Show an error message on the screen.
  void _showError(String message) {
    showEthmarToast(context, message, type: EthmarToastType.error);
  }

  // Create a new account or continue an unfinished registration.
  Future<void> _submit() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    // Check the username, email, and password before continuing.
    if (!(_form.currentState?.validate() ?? false)) return;

    final email = _email.text.trim();
    final password = _password.text;
    final username = _username.text.trim();
    final s = S.of(context);

    // Show the loading state while registration is running.
    setState(() => _loading = true);

    try {
      final existingAccountEmail = _verificationAccountEmail;

      // Create a new account if one was not created earlier.
      if (existingAccountEmail == null) {
        final credential = await _authService.createAccount(
          email: email,
          password: password,
        );

        final createdUser = credential.user;
        final createdEmail = createdUser?.email?.trim();

        // Stop if Firebase did not return the new account.
        if (createdUser == null ||
            createdEmail == null ||
            createdEmail.isEmpty) {
          throw StateError('Firebase did not return the created account.');
        }

        if (!mounted) return;

        // Save the account details for email verification.
        setState(() {
          _verificationAccountId = createdUser.uid;
          _verificationAccountEmail = createdEmail;
        });

      } else if (email.toLowerCase() != existingAccountEmail.toLowerCase()) {
        // Do not switch email addresses during registration.
        _showError(s.errAuthSessionMismatch);
        return;
      }

      // Make sure the current user matches the created account.
      if (!_currentUserMatchesVerificationAccount()) {
        _showError(s.errAuthSessionMismatch);
        return;
      }

      // Skip email verification if the user is already verified.
      if (!await _authService.isEmailVerified()) {

        // Send the email once. The user can resend it from the dialog.
        if (!_verificationSent) {
          await _authService.sendEmailVerification();
          _verificationSent = true;
        }

        if (!mounted) return;

        // Open the dialog and wait for email verification.
        final verified = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => EmailVerificationDialog(
            email: _verificationAccountEmail ?? email,
            authService: _authService,
          ),
        );

        // Return to Login if the user does not complete verification.
        if (verified != true) {
          try {
            await _authService.signOut();
          } catch (_) {
            if (!mounted) return;
            _showError(s.errLogout);
            return;
          }

          if (!mounted) return;

          Navigator.of(context)
              .pushReplacement(riseRoute(LoginScreen(email: email)));

          return;
        }

        if (!mounted) return;
      }

      // Check the account again before saving the profile.
      if (!_currentUserMatchesVerificationAccount()) {
        _showError(s.errAuthSessionMismatch);
        return;
      }

      // Save the user's profile in Firestore.
      await _userService.createCurrentUserProfile(username: username);

      if (!mounted) return;

      // Make sure the account did not change while saving the profile.
      if (!_currentUserMatchesVerificationAccount()) {
        _showError(s.errAuthSessionMismatch);
        return;
      }

      // Show a success message and open Home.
      showEthmarToast(context, s.accountCreated);

      Navigator.of(context).pushAndRemoveUntil(
        riseRoute(HomeScreen(username: username)),
        (_) => false,
      );

    } on FirebaseAuthException catch (error) {
      // Handle Firebase Authentication errors.
      if (!mounted) return;
      _showError(_authErrorMessage(error, s));

    } on UsernameAlreadyTakenException {
      // Tell the user if the username is already taken.
      if (!mounted) return;
      _showError(s.errUsernameTaken);

    } on UserProfileConflictException {
      // Handle problems with the existing user profile.
      if (!mounted) return;
      _showError(s.errProfileConflict);

    } on FirebaseException catch (error) {
      // Handle Firestore errors.
      if (!mounted) return;
      _showError(_firestoreErrorMessage(error, s));

    } on StateError {
      // Handle problems with the current login session.
      if (!mounted) return;
      _showError(s.errAuthSessionMismatch);

    } catch (_) {
      // Show a general message for unexpected errors.
      if (!mounted) return;
      _showError(s.errAuthGeneral);

    } finally {
      // Stop loading when registration finishes or fails.
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

                          // Username input field.
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

                          // Email input field.
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

                          // Password input field.
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

                          // Create account button.
                          EthmarButton(
                            label: s.createButton,
                            showArrow: true,
                            loading: _loading,
                            onPressed: _loading ? null : _submit,
                          ),

                          const SizedBox(height: 12),

                          // Link to the Login screen.
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