# Authentication and User Management — Technical User Stories

## TS-AUTH-01 — Firebase Initialization

**Goal:** Initialize Firebase before the Flutter application starts.

**Acceptance criteria:**

- `Firebase.initializeApp` uses `DefaultFirebaseOptions.currentPlatform`.
- Android uses the configured Ethmar Firebase project.
- Firebase initialization completes before `runApp`.

## TS-AUTH-02 — Register User

**Goal:** Allow a new user to create an account using username, email, and password.

**Acceptance criteria:**

- Inputs are validated.
- A Firebase Authentication account is created.
- A verification email is sent.
- Registration cannot finish before email verification.
- The password is never stored in Firestore.

## TS-AUTH-03 — Verify Email

**Goal:** Require email ownership verification before registration is completed.

**Acceptance criteria:**

- The verification email is sent through Firebase Authentication.
- Verification status is reloaded before it is trusted.
- Unverified users cannot complete registration.
- Verified users can proceed to profile creation.

## TS-AUTH-04 — Unique Username

**Goal:** Guarantee that each visible username is unique regardless of letter case.

**Acceptance criteria:**

- The username is normalized using trim and lowercase.
- `Fanar`, `fanar`, and `FANAR` are treated as the same username.
- `usernames/{normalizedUsername}` stores the reservation.
- Username reservation is enforced in a Firestore transaction.
- A reserved username cannot be claimed by another UID.

## TS-AUTH-05 — Create User Profile

**Goal:** Store the verified user's application profile in Firestore.

**Acceptance criteria:**

- The profile path is `users/{uid}`.
- Stored fields are `username`, `normalizedUsername`, `email`, and `createdAt`.
- `createdAt` uses a server timestamp.
- Profile creation and username reservation are atomic.
- No password is stored.

## TS-AUTH-06 — Login

**Goal:** Allow an existing verified user with a valid profile to log in.

**Acceptance criteria:**

- Firebase Authentication validates the email and password.
- The email must be verified.
- `users/{uid}` is loaded.
- The saved username is used in the application.
- A missing or invalid profile prevents Home access.
- A failed login does not leave an authenticated invalid session.

## TS-AUTH-07 — Logout

**Goal:** Securely end the authenticated session.

**Acceptance criteria:**

- Firebase Authentication signs out.
- The user returns to the unauthenticated screen.
- Navigation history cannot return to Home after logout.

## TS-AUTH-08 — Reset Password

**Goal:** Allow users to request a Firebase password-reset email.

**Acceptance criteria:**

- The email input is validated.
- Firebase Authentication password reset is used.
- The UI does not disclose whether the account exists.
- Firebase errors are handled safely.

## TS-AUTH-09 — Firestore Security

**Goal:** Protect user profiles and username reservations with Firestore Security Rules.

**Acceptance criteria:**

- Authentication and email verification are enforced where required.
- A user cannot read another user's profile.
- Profile fields are restricted.
- Username reservation is tied to the authenticated UID.
- Profile creation and username reservation are validated together.
- Unauthorized updates and deletes are denied.
- Unspecified database access is denied.

## TS-AUTH-10 — Authentication Error Handling

**Goal:** Provide safe, understandable feedback for authentication failures.

**Acceptance criteria:**

- Firebase Authentication errors map to suitable user-facing messages.
- Username conflicts have a clear message.
- Missing or invalid profiles are handled safely.
- Async UI operations do not navigate or update disposed widgets.
- Sensitive internal Firebase details are not exposed unnecessarily.

## TS-AUTH-11 — Authentication Localization

**Goal:** Support the existing Arabic and English localization approach for authentication messages.

**Acceptance criteria:**

- New authentication messages use the existing localization mechanism.
- The username conflict message is available in Arabic and English.
- The reset-password confirmation is available in Arabic and English.
- Unnecessary duplicate hardcoded strings are not introduced.

## TS-AUTH-12 — Authentication Validation

**Goal:** Validate authentication inputs consistently before Firebase requests.

**Acceptance criteria:**

- Email format is validated.
- Passwords use the application's defined validation requirements.
- Usernames contain 3–20 characters.
- Usernames accept only English letters, numbers, periods, and underscores.
- Invalid input is rejected before unnecessary Firebase operations.
