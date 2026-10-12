import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../widgets/auth_header.dart';
import '../widgets/backgrounds.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import 'validators.dart';

/// Password recovery: the user enters their email and we send a reset link.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.email = ''});

  /// Pre-fills the field with whatever was typed on Log in.
  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _authService = AuthService();
  late final _email = TextEditingController(text: widget.email);
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;

    final email = _email.text.trim();
    final s = S.of(context);
    setState(() => _loading = true);
    try {
      await _authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      showEthmarToast(context, s.resetLinkSent);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'user-not-found') {
        // Keep the same response so this screen does not reveal registrations.
        showEthmarToast(context, s.resetLinkSent);
      } else {
        final message = switch (error.code) {
          'invalid-email' => s.errEmailInvalid,
          'too-many-requests' => s.errTooManyRequests,
          'network-request-failed' => s.errNetwork,
          _ => s.errAuthGeneral,
        };
        showEthmarToast(
          context,
          message,
          icon: Icons.error_outline_rounded,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showEthmarToast(
        context,
        s.errAuthGeneral,
        icon: Icons.error_outline_rounded,
      );
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
              title: s.resetTitle,
              accent: s.resetAccent,
              character: 'ethmar_buddy_thinking',
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                  24, 36, 24, 24 + MediaQuery.paddingOf(context).bottom),
              child: Entrance(
                delay: const Duration(milliseconds: 150),
                child: Form(
                  key: _form,
                  child: Column(
                    children: [
                      EthmarTextField(
                        label: s.email,
                        hint: s.emailHint,
                        enabled: !_loading,
                        controller: _email,
                        forceLtr: true,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) => Validators.email(v, s),
                        onSubmitted: _loading ? null : (_) => _submit(),
                      ),
                      const SizedBox(height: 36),
                      EthmarButton(
                        label: s.sendResetLink,
                        showArrow: true,
                        loading: _loading,
                        onPressed: _loading ? null : _submit,
                      ),
                      const SizedBox(height: 12),
                      IgnorePointer(
                        ignoring: _loading,
                        child: EthmarLink(
                          label: s.backToLogin,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }
}
