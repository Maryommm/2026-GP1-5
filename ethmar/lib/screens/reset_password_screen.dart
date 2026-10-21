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

// Allow users to reset their password using their email.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.email = ''});

  // Fill the email field with the email entered on Login.
  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _authService = AuthService();

  // Store the email entered by the user.
  late final _email = TextEditingController(text: widget.email);

  // Track the loading state.
  bool _loading = false;

  // Clear the email controller when the screen closes.
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  // Send a password reset link to the user's email.
  Future<void> _submit() async {
    // Prevent multiple requests at the same time.
    if (_loading) return;

    FocusScope.of(context).unfocus();

    // Check that the email is valid.
    if (!(_form.currentState?.validate() ?? false)) return;

    final email = _email.text.trim();
    final s = S.of(context);

    // Show loading while sending the reset link.
    setState(() => _loading = true);

    try {
      // Request a password reset email from Firebase.
      await _authService.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      // Show a success message after sending the request.
      showEthmarToast(context, s.resetLinkSent);

    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      if (error.code == 'user-not-found') {
        // Do not reveal whether the email is registered.
        showEthmarToast(context, s.resetLinkSent);
      } else {
        // Choose the correct message for Firebase errors.
        final message = switch (error.code) {
          'invalid-email' => s.errEmailInvalid,
          'too-many-requests' => s.errTooManyRequests,
          'network-request-failed' => s.errNetwork,
          _ => s.errAuthGeneral,
        };

        // Show the error message.
        showEthmarToast(
          context,
          message,
          type: EthmarToastType.error,
        );
      }

    } catch (_) {
      // Handle unexpected errors.
      if (!mounted) return;

      showEthmarToast(
        context,
        s.errAuthGeneral,
        type: EthmarToastType.error,
      );

    } finally {
      // Stop loading after the request finishes.
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
            // Password reset screen header.
            AuthHeader(
              title: s.resetTitle,
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
                      // Email input field.
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

                      // Button to send the password reset link.
                      EthmarButton(
                        label: s.sendResetLink,
                        showArrow: true,
                        loading: _loading,
                        onPressed: _loading ? null : _submit,
                      ),

                      const SizedBox(height: 12),

                      // Link to return to the Login screen.
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