import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../widgets/auth_header.dart';
import '../widgets/backgrounds.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/page_routes.dart';
import 'home_placeholder_screen.dart';
import 'login_screen.dart';
import 'validators.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _emailField = GlobalKey<FormFieldState<String>>();
  final _passwordField = GlobalKey<FormFieldState<String>>();
  final _authService = AuthService();
  final _userService = UserService();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _verificationAccountId;
  String? _verificationAccountEmail;

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

  Future<void> _verifyEmail() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final emailIsValid = _emailField.currentState?.validate() ?? false;
    final passwordIsValid = _passwordField.currentState?.validate() ?? false;
    if (!emailIsValid || !passwordIsValid) return;

    final email = _email.text.trim();
    final password = _password.text;
    final existingAccountId = _verificationAccountId;
    final existingAccountEmail = _verificationAccountEmail;
    final s = S.of(context);

    setState(() => _loading = true);
    try {
      if (existingAccountId == null || existingAccountEmail == null) {
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
        if (!mounted) return;
        _showError(s.errAuthSessionMismatch);
        return;
      }

      if (!_currentUserMatchesVerificationAccount()) {
        if (!mounted) return;
        _showError(s.errAuthSessionMismatch);
        return;
      }

      await _authService.sendEmailVerification();
      if (!mounted) return;
      showEthmarToast(context, s.verificationLinkSent);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showError(_authErrorMessage(error, s));
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

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;

    final displayedEmail = _email.text.trim();
    final username = _username.text.trim();
    final accountId = _verificationAccountId;
    final accountEmail = _verificationAccountEmail;
    final s = S.of(context);
    if (accountId == null || accountEmail == null) {
      _showError(s.errVerifyEmailFirst);
      return;
    }
    if (displayedEmail.toLowerCase() != accountEmail.toLowerCase() ||
        !_currentUserMatchesVerificationAccount()) {
      _showError(s.errAuthSessionMismatch);
      return;
    }

    setState(() => _loading = true);
    try {
      final isVerified = await _authService.isEmailVerified();
      if (!mounted) return;
      if (!_currentUserMatchesVerificationAccount()) {
        _showError(s.errAuthSessionMismatch);
        return;
      }
      if (!isVerified) {
        _showError(s.errVerifyEmailFirst);
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
        riseRoute(HomePlaceholderScreen(username: username)),
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
                            fieldKey: _emailField,
                            controller: _email,
                            forceLtr: true,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            validator: (v) => Validators.email(v, s),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: IgnorePointer(
                              ignoring: _loading,
                              child: EthmarLink(
                                label: s.verifyEmail,
                                onTap: _verifyEmail,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          EthmarTextField(
                            label: s.password,
                            hint: s.passwordHint,
                            enabled: !_loading && !_hasVerificationAccount,
                            fieldKey: _passwordField,
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
