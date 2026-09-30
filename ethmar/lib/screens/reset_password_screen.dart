import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
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
  late final _email = TextEditingController(text: widget.email);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;
    // TODO(firebase): FirebaseAuth.instance.sendPasswordResetEmail(
    //   email: _email.text.trim()), then show
    //   showEthmarToast(context, s.resetLinkSent) and pop back to Log in.
    // On FirebaseAuthException 'user-not-found', show
    //   showEthmarToast(context, s.errEmailNotRegistered,
    //   icon: Icons.error_outline_rounded) and stay on this screen.
    // NOTE: Firebase only returns 'user-not-found' here if "Email enumeration
    // protection" is turned OFF (Firebase console > Authentication >
    // Settings > User actions). It's ON by default for new projects, and then
    // unregistered emails silently "succeed".
    showEthmarToast(context, S.of(context).resetSoon,
        icon: Icons.info_outline_rounded);
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
                        controller: _email,
                        forceLtr: true,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) => Validators.email(v, s),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 36),
                      EthmarButton(
                        label: s.sendResetLink,
                        showArrow: true,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 12),
                      EthmarLink(
                        label: s.backToLogin,
                        onTap: () => Navigator.of(context).pop(),
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
