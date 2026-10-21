import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/pending_username_store.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_header.dart';
import '../widgets/backgrounds.dart';
import '../widgets/entrance.dart';
import '../widgets/email_verification_dialog.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/page_routes.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'validators.dart';

// Where the check for the typed username stands.
enum _UsernameStatus { unchecked, checking, available, taken, checkFailed }

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

  // Check the username while the user types, before any account exists.
  final _usernameField = GlobalKey<FormFieldState<String>>();
  _UsernameStatus _usernameStatus = _UsernameStatus.unchecked;
  Timer? _usernameTimer;

  // The name the latest check is for. Results for older names are ignored.
  String _checkedUsername = '';

  // Check if there is an account waiting for verification.
  bool get _hasVerificationAccount =>
      _verificationAccountId != null && _verificationAccountEmail != null;

  @override
  void initState() {
    super.initState();
    _username.addListener(_onUsernameChanged);
    // Redraw so the Create button lights up once every field is correct.
    _email.addListener(_refresh);
    _password.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  // Start a new availability check shortly after the user stops typing.
  void _onUsernameChanged() {
    final name = _username.text.trim().toLowerCase();

    // The listener also fires when only the cursor moves.
    if (name == _checkedUsername) return;

    _checkedUsername = name;
    _usernameTimer?.cancel();
    setState(() {
      _usernameStatus =
          name.isEmpty ? _UsernameStatus.unchecked : _UsernameStatus.checking;
    });
    if (name.isEmpty) return;

    _usernameTimer = Timer(
      const Duration(milliseconds: 500),
      () => _checkUsername(name),
    );
  }

  // Ask Firestore if the name is free. Returns true only if it is free and
  // still the name in the field.
  Future<bool> _checkUsername(String name) async {
    _UsernameStatus status;
    try {
      status = await _userService.isUsernameAvailable(name)
          ? _UsernameStatus.available
          : _UsernameStatus.taken;
    } catch (_) {
      status = _UsernameStatus.checkFailed;
    }

    if (!mounted || name != _checkedUsername) return false;

    setState(() => _usernameStatus = status);

    // Show "taken" right away instead of waiting for the field's own check.
    if (status != _UsernameStatus.available) {
      _usernameField.currentState?.validate();
    }
    return status == _UsernameStatus.available;
  }

  // The field rules plus the result of the availability check.
  String? _usernameError(String? v, S s) {
    final error = Validators.username(v, s);
    if (error != null) return error;

    return switch (_usernameStatus) {
      _UsernameStatus.taken => s.errUsernameTaken,
      _UsernameStatus.checkFailed => s.errUsernameCheckFailed,
      _ => null,
    };
  }

  // True only when every field is correct and the username is free.
  bool _allFieldsValid(S s) =>
      _usernameStatus == _UsernameStatus.available &&
      Validators.username(_username.text, s) == null &&
      Validators.email(_email.text, s) == null &&
      Validators.password(_password.text, s) == null;

  // A spinner while checking the username, a tick once it is free.
  Widget? _usernameStatusIcon() => switch (_usernameStatus) {
        _UsernameStatus.checking => const Padding(
            padding: EdgeInsets.all(15),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        _UsernameStatus.available => const Icon(
            Icons.check_circle_rounded,
            color: AppColors.forest,
            size: 22,
          ),
        _ => null,
      };

  // Clear the text controllers when the screen closes.
  @override
  void dispose() {
    _usernameTimer?.cancel();
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

    // Never create the account while the username is taken or unchecked.
    if (!_allFieldsValid(s)) return;

    // Show the loading state while registration is running.
    setState(() => _loading = true);

    try {
      // Check the username once more, in case someone just took it.
      // Nothing is created and no email is sent if it is no longer free.
      if (!await _checkUsername(_checkedUsername)) return;

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

      // Keep the username on this device, so the profile can still be saved
      // if the app closes before the email is verified.
      await PendingUsernameStore.save(_verificationAccountId!, username);

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
        riseRoute(MainShell(username: username)),
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
                            fieldKey: _usernameField,
                            keyboardType: TextInputType.text,
                            autofillHints: const [AutofillHints.newUsername],
                            inputFormatters: Validators.usernameFormatters,
                            validator: (v) => _usernameError(v, s),
                            suffixIcon: _usernameStatusIcon(),
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
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (v) => Validators.password(v, s),
                            onSubmitted: _loading ? null : (_) => _submit(),
                          ),

                          const SizedBox(height: 36),

                          // Create account button. Dimmed until every field
                          // is correct and the username is free.
                          EthmarButton(
                            label: s.createButton,
                            showArrow: true,
                            loading: _loading,
                            onPressed: _loading || !_allFieldsValid(s)
                                ? null
                                : _submit,
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