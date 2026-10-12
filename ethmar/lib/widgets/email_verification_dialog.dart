import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'ethmar_buttons.dart';

/// Shared email-verification flow for new registrations and recovery after
/// signing in to an existing unverified Firebase Auth account.
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
  Timer? _timer;
  bool _checking = false;
  bool _manualChecking = false;
  bool _resending = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkVerification(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkVerification();
  }

  Future<void> _checkVerification({bool manual = false}) async {
    if (_checking) return;
    _checking = true;
    if (manual && mounted) {
      setState(() {
        _manualChecking = true;
        _message = null;
      });
    }

    try {
      final verified = await widget.authService.isEmailVerified();
      if (verified && mounted) {
        _timer?.cancel();
        Navigator.of(context).pop(true);
      } else if (manual && mounted) {
        setState(() {
          _message = S.of(context).verificationStillPending;
          _messageIsError = true;
        });
      }
    } on FirebaseAuthException catch (error) {
      if (manual && mounted) {
        setState(() {
          _message = _firebaseMessage(error, S.of(context));
          _messageIsError = true;
        });
      }
    } catch (_) {
      if (manual && mounted) {
        setState(() {
          _message = S.of(context).errAuthGeneral;
          _messageIsError = true;
        });
      }
    } finally {
      _checking = false;
      if (manual && mounted) setState(() => _manualChecking = false);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    final s = S.of(context);
    setState(() {
      _resending = true;
      _message = null;
    });

    try {
      if (await widget.authService.isEmailVerified()) {
        if (!mounted) return;
        _timer?.cancel();
        Navigator.of(context).pop(true);
        return;
      }
      await widget.authService.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _message = s.verificationResent;
        _messageIsError = false;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _firebaseMessage(error, s);
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = s.errAuthGeneral;
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mark_email_unread_rounded,
              size: 56,
              color: AppColors.forest,
            ),
            const SizedBox(height: 16),
            Text(
              widget.recovery ? s.emailNotVerifiedTitle : s.verifyDialogTitle,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 12),
            Text(
              widget.recovery
                  ? s.verificationRecoveryBody(widget.email)
                  : s.verifyDialogBody(widget.email),
              textAlign: TextAlign.center,
              style: AppText.body(context),
            ),
            const SizedBox(height: 20),
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
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: AppText.small(
                  context,
                  color: _messageIsError ? AppColors.error : AppColors.success,
                ),
              ),
            ],
            const SizedBox(height: 24),
            EthmarButton(
              label: s.checkVerification,
              loading: _manualChecking,
              onPressed: _resending
                  ? null
                  : () => _checkVerification(manual: true),
            ),
            const SizedBox(height: 12),
            EthmarButton(
              label: s.resendEmail,
              outlined: true,
              loading: _resending,
              onPressed: _manualChecking ? null : _resend,
            ),
            const SizedBox(height: 8),
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
