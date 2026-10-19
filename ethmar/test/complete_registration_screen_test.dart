import 'package:ethmar/l10n/app_strings.dart';
import 'package:ethmar/screens/complete_registration_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps email verification network errors to the network message', () {
    final strings = S(AppStrings.en);

    final message = completeRegistrationFirebaseErrorMessage(
      FirebaseAuthException(code: 'network-request-failed'),
      strings,
    );

    expect(message, strings.errNetwork);
    expect(message, isNot(strings.errProfileCreate));
  });
}
