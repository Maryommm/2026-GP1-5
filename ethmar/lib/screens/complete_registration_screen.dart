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

/// Finishes an interrupted registration after Firebase Auth email
/// verification succeeded but `users/{uid}` was never created.
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
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;

    final username = _username.text.trim();
    final s = S.of(context);
    setState(() => _loading = true);
    try {
      if (!await _authService.isEmailVerified()) {
        await _returnToLogin();
        return;
      }

      await _userService.createCurrentUserProfile(username: username);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        riseRoute(HomeScreen(username: username)),
        (_) => false,
      );
    } on UsernameAlreadyTakenException {
      if (!mounted) return;
      _showError(s.errUsernameTaken);
    } on UserProfileConflictException {
      if (!mounted) return;
      _showError(s.errProfileConflict);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showError(switch (error.code) {
        'unavailable' || 'deadline-exceeded' => s.errNetwork,
        _ => s.errProfileCreate,
      });
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

  Future<void> _cancel() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await _returnToLogin();
    } catch (_) {
      if (!mounted) return;
      _showError(S.of(context).errLogout);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _returnToLogin() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      riseRoute(LoginScreen(email: widget.email)),
      (_) => false,
    );
  }

  void _showError(String message) {
    showEthmarToast(context, message, icon: Icons.error_outline_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        body: LeafPrintBackground(
          child: SingleChildScrollView(
            child: Column(
              children: [
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
                          Text(
                            s.completeRegistrationBody,
                            textAlign: TextAlign.center,
                            style: AppText.body(context),
                          ),
                          const SizedBox(height: 24),
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
                          EthmarButton(
                            label: s.completeRegistrationButton,
                            showArrow: true,
                            loading: _loading,
                            onPressed: _loading ? null : _complete,
                          ),
                          const SizedBox(height: 12),
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
