import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'ethmar_buttons.dart';

// Show a dialog to verify the user's email.
class EmailVerificationDialog extends StatefulWidget {
  const EmailVerificationDialog({
    super.key,
    required this.email,
    required this.authService,
    this.recovery = false,
  });

  final String email;
  final AuthService authService;
  final bool recovery;

  @override
  State<EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<EmailVerificationDialog>
    with WidgetsBindingObserver {

  // Timer used to check email verification automatically.
  Timer? _timer;

  // Track verification checks and email resending.
  bool _checking = false;
  bool _manualChecking = false;
  bool _resending = false;

  // Store the message shown to the user.
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();

    // Watch when the user returns to the app.
    WidgetsBinding.instance.addObserver(this);

    // Check email verification every 3 seconds.
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkVerification(),
    );
  }

  @override
  void dispose() {
    // Stop the timer when the dialog closes.
    _timer?.cancel();

    // Stop watching app state changes.
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  // Check verification when the user returns to the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkVerification();
  }

  // Check if the user has verified their email.
  Future<void> _checkVerification({bool manual = false}) async {

    // Prevent multiple checks at the same time.
    if (_checking) return;

    _checking = true;

    // Show loading when the user checks manually.
    if (manual && mounted) {
      setState(() {
        _manualChecking = true;
        _message = null;
      });
    }

    try {
      // Get the latest email verification status from Firebase.
      final verified = await widget.authService.isEmailVerified();

      if (verified && mounted) {

        // Stop checking and close the dialog after verification.
        _timer?.cancel();
        Navigator.of(context).pop(true);

      } else if (manual && mounted) {

        // Tell the user if the email is not verified yet.
        setState(() {
          _message = S.of(context).verificationStillPending;
          _messageIsError = true;
        });
      }

    } on FirebaseAuthException catch (error) {

      // Show Firebase errors during manual verification.
      if (manual && mounted) {
        setState(() {
          _message = _firebaseMessage(error, S.of(context));
          _messageIsError = true;
        });
      }

    } catch (_) {

      // Show a general error if verification fails.
      if (manual && mounted) {
        setState(() {
          _message = S.of(context).errAuthGeneral;
          _messageIsError = true;
        });
      }

    } finally {

      // Reset the checking state after finishing.
      _checking = false;

      if (manual && mounted) {
        setState(() => _manualChecking = false);
      }
    }
  }

  // Send another verification email to the user.
  Future<void> _resend() async {

    // Prevent sending multiple emails at the same time.
    if (_resending) return;

    final s = S.of(context);

    // Show loading while sending the email.
    setState(() {
      _resending = true;
      _message = null;
    });

    try {

      // Check if the email was already verified.
      if (await widget.authService.isEmailVerified()) {
        if (!mounted) return;

        _timer?.cancel();
        Navigator.of(context).pop(true);
        return;
      }

      // Send a new verification email.
      await widget.authService.sendEmailVerification();

      if (!mounted) return;

      // Show a success message after sending.
      setState(() {
        _message = s.verificationResent;
        _messageIsError = false;
      });

    } on FirebaseAuthException catch (error) {

      // Show Firebase errors if resending fails.
      if (!mounted) return;

      setState(() {
        _message = _firebaseMessage(error, s);
        _messageIsError = true;
      });

    } catch (_) {

      // Show a general error if resending fails.
      if (!mounted) return;

      setState(() {
        _message = s.errAuthGeneral;
        _messageIsError = true;
      });

    } finally {

      // Stop loading after the resend request finishes.
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  // Show the correct message for Firebase errors.
  String _firebaseMessage(FirebaseAuthException error, S s) {
    return switch (error.code) {
      'too-many-requests' => s.errTooManyRequests,
      'network-request-failed' => s.errNetwork,
      _ => s.errAuthGeneral,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // Email verification icon.
            const Icon(
              Icons.mark_email_unread_rounded,
              size: 56,
              color: AppColors.forest,
            ),

            const SizedBox(height: 16),

            // Show the dialog title.
            Text(
              widget.recovery
                  ? s.emailNotVerifiedTitle
                  : s.verifyDialogTitle,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),

            const SizedBox(height: 12),

            // Show instructions with the user's email.
            Text(
              widget.recovery
                  ? s.verificationRecoveryBody(widget.email)
                  : s.verifyDialogBody(widget.email),
              textAlign: TextAlign.center,
              style: AppText.body(context),
            ),

            const SizedBox(height: 20),

            // Show that the app is waiting for verification.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    s.verifyDialogWaiting,
                    style: AppText.small(
                      context,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            // Show success or error messages.
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: AppText.small(
                  context,
                  color: _messageIsError
                      ? AppColors.error
                      : AppColors.success,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Button to check email verification manually.
            EthmarButton(
              label: s.checkVerification,
              loading: _manualChecking,
              onPressed: _resending
                  ? null
                  : () => _checkVerification(manual: true),
            ),

            const SizedBox(height: 12),

            // Button to resend the verification email.
            EthmarButton(
              label: s.resendEmail,
              outlined: true,
              loading: _resending,
              onPressed: _manualChecking ? null : _resend,
            ),

            const SizedBox(height: 8),

            // Button to cancel email verification.
            EthmarLink(
              label: s.cancel,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}