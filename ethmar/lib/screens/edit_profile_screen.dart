import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../services/profile_image_service.dart';
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

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.username});
  final String username;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _userService = UserService();
  final _profileImageService = ProfileImageService();
  final _imagePicker = ImagePicker();
  late final _username = TextEditingController(text: widget.username);
  StreamSubscription<UploadedProfileImage?>? _profileImageSubscription;
  UploadedProfileImage? _uploadedProfileImage;
  bool _saving = false;
  bool _photoBusy = false;

  bool get _hasChanges => _username.text.trim() != widget.username;

  @override
  void initState() {
    super.initState();
    _profileImageSubscription = _profileImageService
        .watchCurrentProfileImage()
        .listen(
          (image) {
            if (mounted) setState(() => _uploadedProfileImage = image);
          },
          onError: (Object _, StackTrace __) {
            // Keep the initial fallback if Firestore is temporarily unavailable.
            if (mounted) setState(() => _uploadedProfileImage = null);
          },
        );
  }

  @override
  void dispose() {
    _profileImageSubscription?.cancel();
    _profileImageService.close();
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _photoBusy) return;
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

  Future<void> _chooseAndUploadPhoto(ImageSource source) async {
    if (_saving || _photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 4096,
        maxHeight: 4096,
        requestFullMetadata: false,
      );
      if (image == null) return;

      final uploaded = await _profileImageService.upload(image);
      if (!mounted) return;
      setState(() => _uploadedProfileImage = uploaded);
      showEthmarToast(context, S.of(context).profilePhotoUploaded);
    } on ProfileImageException catch (error) {
      if (!mounted) return;
      _showError(_profilePhotoError(S.of(context), error));
    } catch (_) {
      if (!mounted) return;
      _showError(S.of(context).errProfilePhotoPick);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _deletePhoto() async {
    if (_uploadedProfileImage == null || _saving || _photoBusy) {
      return;
    }
    setState(() => _photoBusy = true);
    try {
      await _profileImageService.delete();
      if (!mounted) return;
      setState(() => _uploadedProfileImage = null);
      showEthmarToast(context, S.of(context).profilePhotoDeleted);
    } on ProfileImageException catch (error) {
      if (!mounted) return;
      _showError(_profilePhotoError(S.of(context), error));
    } catch (_) {
      if (!mounted) return;
      _showError(S.of(context).errProfilePhotoServer);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  String _profilePhotoError(S s, ProfileImageException error) {
    final message = switch (error.code) {
      ProfileImageErrorCode.unauthenticated ||
      ProfileImageErrorCode.unauthorized => s.errProfilePhotoAuth,
      ProfileImageErrorCode.emailNotVerified => s.errProfilePhotoVerification,
      ProfileImageErrorCode.unsupportedImage => s.errProfilePhotoType,
      ProfileImageErrorCode.imageTooLarge => s.errProfilePhotoSize,
      ProfileImageErrorCode.network => s.errNetwork,
      ProfileImageErrorCode.rateLimited => s.errProfilePhotoRateLimit,
      ProfileImageErrorCode.metadata => s.errProfilePhotoSave,
      ProfileImageErrorCode.server ||
      ProfileImageErrorCode.invalidResponse => s.errProfilePhotoServer,
    };
    final diagnostic = error.safeDiagnostic;
    return diagnostic == null ? message : '$message\n[$diagnostic]';
  }

  /// Cancel, the back arrow and the system back all come here.
  Future<void> _leave() async {
    if (_saving || _photoBusy) return;
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
                          _PhotoArea(
                            username: widget.username,
                            imageUrl: _uploadedProfileImage?.secureUrl,
                            loading: _photoBusy,
                            onTakePhoto: () =>
                                _chooseAndUploadPhoto(ImageSource.camera),
                            onChooseFromGallery: () =>
                                _chooseAndUploadPhoto(ImageSource.gallery),
                            onDelete: _uploadedProfileImage != null
                                ? _deletePhoto
                                : null,
                          ),
                          const SizedBox(height: 28),
                          EthmarTextField(
                            label: s.username,
                            hint: s.usernameHint,
                            enabled: !_saving && !_photoBusy,
                            controller: _username,
                            forceLtr: true,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            validator: (v) => Validators.username(v, s),
                            onSubmitted: _saving || _photoBusy
                                ? null
                                : (_) => _save(),
                          ),
                          const SizedBox(height: 28),
                          EthmarButton(
                            label: s.save,
                            loading: _saving,
                            onPressed: _saving || _photoBusy ? null : _save,
                          ),
                          const SizedBox(height: 12),
                          EthmarButton(
                            label: s.cancel,
                            outlined: true,
                            onPressed: _saving || _photoBusy ? null : _leave,
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
// Profile photo controls. Metadata lives in users/{uid}/media/profile, so the
// four-field users/{uid} profile remains unchanged.
// ---------------------------------------------------------------------------

class _PhotoArea extends StatelessWidget {
  const _PhotoArea({
    required this.username,
    required this.imageUrl,
    required this.loading,
    required this.onTakePhoto,
    required this.onChooseFromGallery,
    required this.onDelete,
  });

  final String username;
  final String? imageUrl;
  final bool loading;
  final VoidCallback onTakePhoto;
  final VoidCallback? onChooseFromGallery;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(username: username, size: 96, imageUrl: imageUrl),
            if (loading)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x66000000),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.surface,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
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
                  onTap: loading ? null : onTakePhoto,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: 18,
                      color: AppColors.onForest,
                    ),
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
            _PhotoPill(
              icon: Icons.photo_camera_outlined,
              label: s.takePhoto,
              onTap: loading ? null : onTakePhoto,
            ),
            _PhotoPill(
              icon: Icons.photo_library_outlined,
              label: s.chooseFromGallery,
              onTap: loading ? null : onChooseFromGallery,
            ),
            if (onDelete != null)
              _PhotoPill(
                icon: Icons.delete_outline_rounded,
                label: s.deletePhoto,
                onTap: loading ? null : onDelete,
              ),
          ],
        ),
      ],
    );
  }
}

/// Small tinted pill, the same colours as the outlined [EthmarButton].
class _PhotoPill extends StatelessWidget {
  const _PhotoPill({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forestTint,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
