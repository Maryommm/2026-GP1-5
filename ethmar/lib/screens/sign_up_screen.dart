import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
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
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    // TODO(firebase): 1) Check the username is free in Firestore
    //   (`usernames/{username.toLowerCase()}`); if taken, show errUsernameTaken.
    // 2) FirebaseAuth.createUserWithEmailAndPassword(email, password).
    // 3) In one transaction, write `usernames/{lowercased}` -> {uid} and
    //   `users/{uid}` -> {username, email, createdAt} so two people can't
    //   claim the same username at the same time.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _loading = false);
    showEthmarToast(context, S.of(context).accountCreated);
    Navigator.of(context).pushAndRemoveUntil(
      riseRoute(HomePlaceholderScreen(username: _username.text.trim())),
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
              title: s.signUpTitle,
              accent: s.signUpAccent,
              character: 'ethmar_buddy_seedling',
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
                          label: s.username,
                          hint: s.usernameHint,
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
                          controller: _email,
                          forceLtr: true,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: (v) => Validators.email(v, s),
                        ),
                        const SizedBox(height: 20),
                        EthmarTextField(
                          label: s.password,
                          hint: s.passwordHint,
                          controller: _password,
                          isPassword: true,
                          forceLtr: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          validator: (v) => Validators.password(v, s),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 36),
                        EthmarButton(
                          label: s.createButton,
                          showArrow: true,
                          loading: _loading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 12),
                        AuthFooter(
                          question: s.alreadyHaveAccount,
                          action: s.logInLink,
                          onTap: () => Navigator.of(context)
                              .pushReplacement(riseRoute(const LoginScreen())),
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
