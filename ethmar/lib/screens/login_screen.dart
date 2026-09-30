import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../widgets/auth_header.dart';
import '../widgets/backgrounds.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/page_routes.dart';
import 'home_placeholder_screen.dart';
import 'sign_up_screen.dart';
import 'validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
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
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    // TODO: connect to your backend (e.g. Firebase Auth) here.
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushAndRemoveUntil(
      riseRoute(const HomePlaceholderScreen()),
      (_) => false,
    );
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
                  24, 36, 24, 24 + MediaQuery.paddingOf(context).bottom),
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
                          controller: _password,
                          isPassword: true,
                          forceLtr: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          validator: (v) => Validators.passwordRequired(v, s),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: EthmarLink(
                            label: s.forgotPassword,
                            onTap: () => showEthmarToast(context, s.resetSoon,
                                icon: Icons.info_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 24),
                        EthmarButton(
                          label: s.loginButton,
                          showArrow: true,
                          loading: _loading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 12),
                        AuthFooter(
                          question: s.newHere,
                          action: s.createAccountLink,
                          onTap: () => Navigator.of(context)
                              .pushReplacement(riseRoute(const SignUpScreen())),
                        ),
                      ],
                    ),
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
