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
  final _emailField = GlobalKey<FormFieldState<String>>();
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

  void _verifyEmail() {
    FocusScope.of(context).unfocus();
    if (!(_emailField.currentState?.validate() ?? false)) return;
    // TODO(firebase): Firebase only sends verification links to a signed-in
    // user, so this link starts the account:
    // 1) Validate the password field too (it's needed to create the user).
    // 2) createUserWithEmailAndPassword(email, password) — or, if this user
    //   already exists from an earlier tap, just resend.
    // 3) currentUser!.sendEmailVerification(), then toast "Link sent".
    // Handle FirebaseAuthException 'email-already-in-use' with a friendly error.
    showEthmarToast(context, S.of(context).verifySoon,
        icon: Icons.info_outline_rounded);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    // TODO(firebase): Finish creating the account (the Auth user already
    // exists from the "Verify email" link):
    // 1) await currentUser!.reload(); if currentUser is null (link never
    //   tapped) or !currentUser!.emailVerified, set _loading = false, show
    //   showEthmarToast(context, s.errVerifyEmailFirst,
    //   icon: Icons.error_outline_rounded) and return — no account is saved.
    // 2) Check the username is free in Firestore
    //   (`usernames/{username.toLowerCase()}`); if taken, show errUsernameTaken.
    // 3) In one transaction, write `usernames/{lowercased}` -> {uid} and
    //   `users/{uid}` -> {username, email, createdAt} so two people can't
    //   claim the same username at the same time.
    // 4) Only then show the success toast and go Home (below). On any
    //   FirebaseException, set _loading = false and show an error instead.
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
                          child: EthmarLink(
                            label: s.verifyEmail,
                            onTap: _verifyEmail,
                          ),
                        ),
                        const SizedBox(height: 8),
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
