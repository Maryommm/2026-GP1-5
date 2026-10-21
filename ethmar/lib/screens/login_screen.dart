import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/startup_service.dart';
import '../services/user_service.dart';
import '../widgets/auth_header.dart';
import '../widgets/backgrounds.dart';
import '../widgets/entrance.dart';
import '../widgets/email_verification_dialog.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/page_routes.dart';
import 'main_shell.dart';
import 'reset_password_screen.dart';
import 'sign_up_screen.dart';
import 'validators.dart';

// Screen for signing in to an existing account.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.email = '',
    this.resumePersistedSession = false,
    this.startupFailure,
  });

  // Store the email and startup information.
  final String email;
  final bool resumePersistedSession;
  final StartupFailure? startupFailure;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _authService = AuthService();
  final _userService = UserService();

  // Store the email and password entered by the user.
  late final TextEditingController _email;
  final _password = TextEditingController();

  // Track the login loading state.
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    // Fill the email field if an email was provided.
    _email = TextEditingController(text: widget.email);

    // Handle startup errors or restore an existing login session.
    if (widget.startupFailure != null || widget.resumePersistedSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        // Show an error if startup failed.
        final failure = widget.startupFailure;
        if (failure != null) {
          _showError(_startupFailureMessage(failure, S.of(context)));
        }

        // Continue login using the saved Firebase session.
        if (widget.resumePersistedSession) {
          await _resumePersistedSession();
        }
      });
    }
  }

  // Clear the text controllers when the screen closes.
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // Check the form and sign in with email and password.
  Future<void> _submit() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    // Check that the email and password are valid.
    if (!(_form.currentState?.validate() ?? false)) return;

    final email = _email.text.trim();
    final password = _password.text;

    // Start the login process.
    await _runAuthenticatedFlow(
      email: email,
      sessionProvider: () async {
        // Sign in using Firebase Authentication.
        final credential = await _authService.signIn(
          email: email,
          password: password,
        );

        // Get the signed-in user's ID.
        final uid = credential.user?.uid;

        if (uid == null) {
          throw StateError('Firebase did not return the signed-in user.');
        }

        return uid;
      },
    );
  }

  // Continue login using an existing Firebase session.
  Future<void> _resumePersistedSession() async {
    await _runAuthenticatedFlow(
      email: widget.email,
      sessionProvider: () async {
        // Get the user from the saved session.
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          throw StateError('No persisted Firebase session is available.');
        }

        return user.uid;
      },
    );
  }

  // Handle login, session checks, and errors.
  Future<void> _runAuthenticatedFlow({
    required String email,
    required Future<String> Function() sessionProvider,
  }) async {
    if (_loading) return;

    final s = S.of(context);

    // Show loading while checking the account.
    setState(() => _loading = true);

    try {
      // Get the user ID and complete the login process.
      final uid = await sessionProvider();

      await _finishAuthenticatedSession(uid: uid, email: email, s: s);

    } on FirebaseAuthException catch (error) {
      // Keep the session if the error is caused by the network.
      if (error.code != 'network-request-failed') await _signOutQuietly();

      if (!mounted) return;
      _showError(_authErrorMessage(error, s));

    } on UserProfileInvalidException {
      // Sign out if the user's profile contains invalid data.
      await _signOutQuietly();

      if (!mounted) return;
      _showError(s.errProfileLoad);

    } on FirebaseException catch (error) {
      // Keep the session for temporary Firestore connection errors.
      if (error.code != 'unavailable' && error.code != 'deadline-exceeded') {
        await _signOutQuietly();
      }

      if (!mounted) return;
      _showError(_firestoreErrorMessage(error, s));

    } on StateError {
      // Sign out if the login session is invalid.
      await _signOutQuietly();

      if (!mounted) return;
      _showError(s.errAuthGeneral);

    } catch (_) {
      // Handle unexpected login errors.
      await _signOutQuietly();

      if (!mounted) return;
      _showError(s.errAuthGeneral);

    } finally {
      // Stop loading when the login process finishes.
      if (mounted) setState(() => _loading = false);
    }
  }

  // Check email verification and load the user's profile.
  Future<void> _finishAuthenticatedSession({
    required String uid,
    required String email,
    required S s,
  }) async {
    // Check if the user's email is verified.
    var isVerified = await _authService.isEmailVerified();

    var currentUser = FirebaseAuth.instance.currentUser;

    // Make sure the signed-in user has not changed.
    if (currentUser == null || currentUser.uid != uid) {
      throw StateError('The authenticated user changed during sign-in.');
    }

    // Ask the user to verify their email if needed.
    if (!isVerified) {
      if (!mounted) return;

      isVerified =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => EmailVerificationDialog(
              email: currentUser?.email ?? email,
              authService: _authService,
              recovery: true,
            ),
          ) ==
          true;

      // Stop login if email verification was not completed.
      if (!isVerified) {
        final signedOut = await _signOutQuietly();

        if (!signedOut && mounted) _showError(s.errLogout);
        return;
      }
    }

    // Check the user again after email verification.
    currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null ||
        currentUser.uid != uid ||
        !currentUser.emailVerified) {
      throw StateError('The authenticated user changed during verification.');
    }

    late final String username;

    try {
      // Load the username from Firestore.
      username = await _userService.getCurrentUsername();

    } on UserProfileMissingException {
      // The sign up was never finished. Save the profile with the username
      // chosen at sign up, or remove the account so the email can sign up
      // again.
      final finished = await _userService.finishUnfinishedSignUp();

      if (finished == null) {
        if (mounted) _showError(s.errSignUpUnfinished);
        return;
      }

      username = finished;
    }

    if (!mounted) return;

    // Make sure the same user is still signed in.
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('The authenticated user changed while loading.');
    }

    // Open Home after successful login.
    Navigator.of(context).pushAndRemoveUntil(
      riseRoute(MainShell(username: username)),
      (_) => false,
    );
  }

  // Show the correct message for startup errors.
  String _startupFailureMessage(StartupFailure failure, S s) =>
      switch (failure) {
        StartupFailure.authentication => s.errAuthGeneral,
        StartupFailure.network => s.errNetwork,
        StartupFailure.profile => s.errProfileLoad,
        StartupFailure.unfinishedSignUp => s.errSignUpUnfinished,
        StartupFailure.logInToFinishSignUp => s.errSignUpUnfinishedLogIn,
      };

  // Show the correct message for Firebase Auth errors.
  String _authErrorMessage(FirebaseAuthException error, S s) {
    return switch (error.code) {
      'invalid-email' => s.errEmailInvalid,
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' ||
      'user-disabled' => s.errInvalidCredentials,
      'too-many-requests' => s.errTooManyRequests,
      'network-request-failed' => s.errNetwork,
      _ => s.errAuthGeneral,
    };
  }

  // Show the correct message for Firestore errors.
  String _firestoreErrorMessage(FirebaseException error, S s) {
    return switch (error.code) {
      'unavailable' || 'deadline-exceeded' => s.errNetwork,
      _ => s.errProfileLoad,
    };
  }

  // Sign out safely without replacing the original error.
  Future<bool> _signOutQuietly() async {
    try {
      await _authService.signOut();
      return true;
    } catch (_) {
      // Keep the original error if sign-out also fails.
      return false;
    }
  }

  // Show an error message on the screen.
  void _showError(String message) {
    showEthmarToast(context, message, type: EthmarToastType.error);
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
                title: s.loginTitle,
                character: 'ethmar_buddy_waving',
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
                          // Email input field.
                          EthmarTextField(
                            label: s.email,
                            hint: s.emailHint,
                            enabled: !_loading,
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
                            hint: '••••••••',
                            enabled: !_loading,
                            controller: _password,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            validator: (v) => Validators.passwordRequired(v, s),
                            onSubmitted: _loading ? null : (_) => _submit(),
                          ),

                          const SizedBox(height: 4),

                          // Link to reset the password.
                          IgnorePointer(
                            ignoring: _loading,
                            child: Align(
                              // Right side in both languages.
                              alignment: Alignment.centerRight,
                              child: EthmarLink(
                                label: s.forgotPassword,
                                onTap: () => Navigator.of(context).push(
                                  riseRoute(
                                    ResetPasswordScreen(
                                      email: _email.text.trim(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Login button.
                          EthmarButton(
                            label: s.loginButton,
                            showArrow: true,
                            loading: _loading,
                            onPressed: _loading ? null : _submit,
                          ),

                          const SizedBox(height: 12),

                          // Link to create a new account.
                          IgnorePointer(
                            ignoring: _loading,
                            child: AuthFooter(
                              question: s.newHere,
                              action: s.createAccountLink,
                              onTap: () => Navigator.of(context)
                                  .pushReplacement(
                                    riseRoute(const SignUpScreen()),
                                  ),
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