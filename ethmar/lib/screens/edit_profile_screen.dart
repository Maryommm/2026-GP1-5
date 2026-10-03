import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart';
import '../widgets/backgrounds.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/user_avatar.dart';
import 'validators.dart';

/// Edit Profile: the same header and form style as Sign Up / Log in.
/// The username can be changed for real; the profile photo controls are
/// placeholders for now. Leaving with unsaved changes asks first.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.username});
  final String username;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _userService = UserService();
  late final _username = TextEditingController(text: widget.username);
  bool _saving = false;

  bool get _hasChanges => _username.text.trim() != widget.username;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;

    final s = S.of(context);
    final newUsername = _username.text.trim();

    // Nothing changed: no database write, just go back.
    if (newUsername == widget.username) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);
    try {
      await _userService.updateCurrentUsername(newUsername);
      if (!mounted) return;
      // Only shown once Firestore has actually saved the change.
      showEthmarToast(context, s.profileUpdated);
      Navigator.of(context).pop();
    } on UsernameAlreadyTakenException {
      if (!mounted) return;
      _showError(s.errUsernameInUse);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showError(switch (error.code) {
        'unavailable' || 'deadline-exceeded' => s.errNetwork,
        _ => s.errProfileUpdate,
      });
    } catch (_) {
      if (!mounted) return;
      _showError(s.errProfileUpdate);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    showEthmarToast(context, message, icon: Icons.error_outline_rounded);
  }

  /// Cancel, the back arrow and the system back all come here.
  Future<void> _leave() async {
    if (_saving) return;
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await _confirmDiscard();
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<bool?> _confirmDiscard() {
    final s = S.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.discardChangesTitle,
                textAlign: TextAlign.center,
                style: AppText.title(context).copyWith(fontSize: 22),
              ),
              const SizedBox(height: 24),
              EthmarButton(
                label: s.keepEditing,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              const SizedBox(height: 12),
              EthmarButton(
                label: s.discard,
                outlined: true,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Back (arrow or system gesture) never closes the screen directly, so
    // unsaved changes can be confirmed first.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: LeafPrintBackground(
          child: SingleChildScrollView(
            child: Column(
              children: [
                AuthHeader(
                  title: s.editProfileTitle,
                  accent: s.editProfileAccent,
                  character: 'ethmar_buddy_seedling',
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    24,
                    28,
                    24,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Entrance(
                    delay: const Duration(milliseconds: 150),
                    child: Form(
                      key: _form,
                      child: Column(
                        children: [
                          _PhotoArea(username: widget.username),
                          const SizedBox(height: 28),
                          EthmarTextField(
                            label: s.username,
                            hint: s.usernameHint,
                            enabled: !_saving,
                            controller: _username,
                            forceLtr: true,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            validator: (v) => Validators.username(v, s),
                            onSubmitted: _saving ? null : (_) => _save(),
                          ),
                          const SizedBox(height: 28),
                          EthmarButton(
                            label: s.save,
                            loading: _saving,
                            onPressed: _saving ? null : _save,
                          ),
                          const SizedBox(height: 12),
                          EthmarButton(
                            label: s.cancel,
                            outlined: true,
                            onPressed: _saving ? null : _leave,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile photo area: avatar with a camera badge, and the Take Photo /
// Choose from Gallery pills. Placeholders for now: tapping does nothing.
//
// TODO(profile-photo): connect these placeholders to real camera
//   (Take Photo) and gallery (Choose from Gallery) picking,
//   e.g. the image_picker package.
// TODO(profile-photo): upload the picked image to Firebase Storage
//   (e.g. users/{uid}/profile.jpg).
// TODO(profile-photo): save the image reference (URL/path) in the user
//   document — needs a new field + Firestore rules + UserService
//   validation update (the profile currently allows exactly 4 fields).
// TODO(profile-photo): replace or remove the old stored image when the
//   user picks a new one or removes it.
// ---------------------------------------------------------------------------

class _PhotoArea extends StatelessWidget {
  const _PhotoArea({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(username: username, size: 96),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: AppColors.forest,
                shape: const CircleBorder(
                  side: BorderSide(color: AppColors.background, width: 3),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {},
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.photo_camera_rounded,
                        size: 18, color: AppColors.onForest),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _PhotoPill(icon: Icons.photo_camera_outlined, label: s.takePhoto),
            _PhotoPill(
                icon: Icons.photo_library_outlined, label: s.chooseFromGallery),
          ],
        ),
      ],
    );
  }
}

/// Small tinted pill, the same colours as the outlined [EthmarButton].
class _PhotoPill extends StatelessWidget {
  const _PhotoPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forestTint,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.forest),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppText.label(context)
                    .copyWith(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
