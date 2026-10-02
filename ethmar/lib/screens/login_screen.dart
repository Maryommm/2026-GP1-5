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
import 'reset_password_screen.dart';
import 'sign_up_screen.dart';
import 'validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _authService = AuthService();
  final _userService = UserService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;

    final email = _email.text.trim();
    final password = _password.text;
    final s = S.of(context);
    String? signedInUserId;

    setState(() => _loading = true);
    try {
      final credential = await _authService.signIn(
        email: email,
        password: password,
      );
      signedInUserId = credential.user?.uid;
      if (signedInUserId == null) {
        throw StateError('Firebase did not return the signed-in user.');
      }

      final isVerified = await _authService.isEmailVerified();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != signedInUserId) {
        throw StateError('The authenticated user changed during sign-in.');
      }
      if (!isVerified) {
        await _signOutQuietly();
        if (!mounted) return;
        _showError(s.errVerifyEmailFirst);
        return;
      }

      final username = await _userService.getCurrentUsername();
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != signedInUserId) {
        throw StateError('The authenticated user changed while loading.');
      }

      Navigator.of(context).pushAndRemoveUntil(
        riseRoute(HomePlaceholderScreen(username: username)),
        (_) => false,
      );
    } on FirebaseAuthException catch (error) {
      await _signOutQuietly();
      if (!mounted) return;
      _showError(_authErrorMessage(error, s));
    } on UserProfileMissingException {
      await _signOutQuietly();
      if (!mounted) return;
      _showError(s.errProfileMissing);
    } on UserProfileInvalidException {
      await _signOutQuietly();
      if (!mounted) return;
      _showError(s.errProfileLoad);
    } on FirebaseException catch (error) {
      await _signOutQuietly();
      if (!mounted) return;
      _showError(_firestoreErrorMessage(error, s));
    } on StateError {
      await _signOutQuietly();
      if (!mounted) return;
      _showError(s.errAuthGeneral);
    } catch (_) {
      await _signOutQuietly();
      if (!mounted) return;
      _showError(s.errAuthGeneral);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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

  String _firestoreErrorMessage(FirebaseException error, S s) {
    return switch (error.code) {
      'unavailable' || 'deadline-exceeded' => s.errNetwork,
      _ => s.errProfileLoad,
    };
  }

  Future<void> _signOutQuietly() async {
    try {
      await _authService.signOut();
    } catch (_) {
      // The original error is more useful to the user than a cleanup failure.
    }
  }

  void _showError(String message) {
    showEthmarToast(context, message, icon: Icons.error_outline_rounded);
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
                accent: s.loginAccent,
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
                          EthmarTextField(
                            label: s.password,
                            hint: '••••••••',
                            enabled: !_loading,
                            controller: _password,
                            isPassword: true,
                            forceLtr: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            validator: (v) => Validators.passwordRequired(v, s),
                            onSubmitted: _loading ? null : (_) => _submit(),
                          ),
                          const SizedBox(height: 4),
                          IgnorePointer(
                            ignoring: _loading,
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
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
                          EthmarButton(
                            label: s.loginButton,
                            showArrow: true,
                            loading: _loading,
                            onPressed: _loading ? null : _submit,
                          ),
                          const SizedBox(height: 12),
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
