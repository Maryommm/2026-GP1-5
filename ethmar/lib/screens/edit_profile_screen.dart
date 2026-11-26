import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_strings.dart';
import '../services/profile_image_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart';
import '../widgets/backgrounds.dart';
import '../widgets/centered_header.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/user_avatar.dart';
import 'validators.dart';

// Allow users to edit their username and profile photo.
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

  // Store the username entered by the user.
  late final _username = TextEditingController(text: widget.username);

  // Listen for changes to the profile photo.
  StreamSubscription<UploadedProfileImage?>? _profileImageSubscription;

  // Store the current uploaded photo.
  UploadedProfileImage? _uploadedProfileImage;

  // Photo changes wait here until Save, so Cancel keeps the saved photo as
  // it was. This is either a newly picked photo (and its bytes, to show it)
  // or a request to delete the saved one.
  XFile? _pendingPhoto;
  Uint8List? _pendingPhotoBytes;
  bool _pendingDelete = false;

  // The username as saved. It starts as the one passed in, and is updated if
  // Save stores the username but then fails on the photo, so a retry doesn't
  // save the username twice.
  late String _savedUsername = widget.username;

  // Track saving and picking a photo.
  bool _saving = false;
  bool _photoBusy = false;

  bool get _usernameChanged => _username.text.trim() != _savedUsername;
  bool get _photoChanged => _pendingPhoto != null || _pendingDelete;

  // Check if anything has changed since the screen opened.
  bool get _hasChanges => _usernameChanged || _photoChanged;

  // Whether a photo is shown right now (saved or pending).
  bool get _hasPhoto =>
      _pendingPhoto != null || (_uploadedProfileImage != null && !_pendingDelete);

  @override
  void initState() {
    super.initState();

    // Listen for profile photo updates from Firestore.
    _profileImageSubscription = _profileImageService
        .watchCurrentProfileImage()
        .listen(
          (image) {
            // Update the displayed photo when it changes.
            if (mounted) setState(() => _uploadedProfileImage = image);
          },
          onError: (Object _, StackTrace __) {
            // Use the default avatar if the photo cannot be loaded.
            if (mounted) setState(() => _uploadedProfileImage = null);
          },
        );
  }

  @override
  void dispose() {
    // Stop listening and release resources.
    _profileImageSubscription?.cancel();
    _profileImageService.close();
    _username.dispose();
    super.dispose();
  }

  // Save the username and any photo change. Nothing is sent to the server
  // before this, so leaving without saving keeps the profile as it was.
  Future<void> _save() async {
    // Prevent saving during another operation.
    if (_saving || _photoBusy) return;

    FocusScope.of(context).unfocus();

    // Check that the username is valid.
    if (!(_form.currentState?.validate() ?? false)) return;

    final s = S.of(context);
    final newUsername = _username.text.trim();

    // Return without saving if nothing has changed.
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    // Show loading while saving.
    setState(() => _saving = true);

    try {
      // Update the username and its reservation in Firestore.
      if (_usernameChanged) {
        await _userService.updateCurrentUsername(newUsername);
        _savedUsername = newUsername;
      }

      // Upload the new photo, or delete the saved one.
      final photo = _pendingPhoto;
      if (photo != null) {
        final uploaded = await _profileImageService.upload(photo);
        if (mounted) setState(() => _uploadedProfileImage = uploaded);
      } else if (_pendingDelete) {
        await _profileImageService.delete();
        if (mounted) setState(() => _uploadedProfileImage = null);
      }
      _clearPendingPhoto();

      if (!mounted) return;

      // Show success only after saving.
      showEthmarToast(context, s.profileUpdated);

      // Return to the Profile screen.
      Navigator.of(context).pop();

    } on ProfileImageException catch (error) {
      // The username (if changed) is saved. The photo change is kept so Save
      // can try it again.
      if (!mounted) return;
      _showError(_profilePhotoError(s, error));

    } on UsernameAlreadyTakenException {
      // Show an error if the username is already taken.
      if (!mounted) return;
      _showError(s.errUsernameInUse);

    } on FirebaseException catch (error) {
      // Handle Firestore and network errors.
      if (!mounted) return;
      _showError(switch (error.code) {
        'unavailable' || 'deadline-exceeded' => s.errNetwork,
        _ => s.errProfileUpdate,
      });

    } catch (_) {
      // Handle unexpected errors.
      if (!mounted) return;
      _showError(s.errProfileUpdate);

    } finally {
      // Stop loading after saving finishes.
      if (mounted) setState(() => _saving = false);
    }
  }

  // Show an error message to the user.
  void _showError(String message) {
    showEthmarToast(context, message, type: EthmarToastType.error);
  }

  void _clearPendingPhoto() {
    _pendingPhoto = null;
    _pendingPhotoBytes = null;
    _pendingDelete = false;
  }

  // Choose a photo and show it. It is uploaded on Save.
  Future<void> _choosePhoto(ImageSource source) async {
    // Prevent multiple operations at the same time.
    if (_saving || _photoBusy) return;

    setState(() => _photoBusy = true);

    // Null until the camera or gallery returns a file, so we can tell if the
    // error happened while picking or while checking the photo.
    XFile? image;

    try {
      // The camera needs permission first; the gallery does not.
      if (source == ImageSource.camera && !await _ensureCameraAccess()) return;

      // Open the camera or gallery to select a photo.
      image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 4096,
        maxHeight: 4096,
        requestFullMetadata: false,
      );

      // The user cancelled: no message.
      if (image == null) return;

      // Check the size and type now, so a bad file is refused right away
      // rather than on Save.
      final bytes = await _profileImageService.readValidImage(image);

      if (!mounted) return;

      // Show the new photo; it replaces any pending delete.
      setState(() {
        _pendingPhoto = image;
        _pendingPhotoBytes = bytes;
        _pendingDelete = false;
      });

    } on ProfileImageException catch (error) {
      // Show the correct profile photo error.
      if (!mounted) return;
      _showError(_profilePhotoError(S.of(context), error));

    } catch (error) {
      if (!mounted) return;
      if (image == null) {
        // Failed while opening the camera or gallery.
        await _handlePickerError(source, error);
      } else {
        // Failed after a photo was chosen, for a reason the check couldn't find.
        _showError(S.of(context).errImageRead);
      }

    } finally {
      // Stop loading after the photo operation finishes.
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  // Explain a camera or gallery error using image_picker's error code.
  // Unknown errors get a general message for the action that failed.
  Future<void> _handlePickerError(ImageSource source, Object error) async {
    final code = error is PlatformException ? error.code : null;

    if (code == 'camera_access_denied') {
      // Only point to Settings if Android won't ask again. A normal "no" needs
      // no message.
      final status = await Permission.camera.status;
      if (status.isPermanentlyDenied || status.isRestricted) {
        await _showCameraSettingsDialog();
      }
      return;
    }

    if (!mounted) return;
    final s = S.of(context);
    _showError(switch (code) {
      'no_available_camera' => s.errCameraOpen,
      'no_valid_image_uri' => s.errImageRead,
      _ => source == ImageSource.camera ? s.errPhotoCapture : s.errPhotoSelect,
    });
  }

  // Make sure the camera can be used. Shows Android's own prompt when it
  // can still ask, and the Settings dialog only when it can't.
  // If the user just says "Don't allow", we accept it quietly.
  Future<bool> _ensureCameraAccess() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;

    if (!status.isPermanentlyDenied && !status.isRestricted) {
      status = await Permission.camera.request();
      if (status.isGranted) return true;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      await _showCameraSettingsDialog();
    }
    return false;
  }

  // Explain that camera access is off and offer to open the app settings.
  Future<void> _showCameraSettingsDialog() async {
    if (!mounted) return;
    final s = S.of(context);

    final openSettings = await showDialog<bool>(
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
                s.cameraAccessTitle,
                textAlign: TextAlign.center,
                style: AppText.title(context).copyWith(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                s.cameraAccessBody,
                textAlign: TextAlign.center,
                style: AppText.body(context),
              ),
              const SizedBox(height: 24),
              EthmarButton(
                label: s.openSettings,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
              const SizedBox(height: 12),
              EthmarButton(
                label: s.cancel,
                outlined: true,
                color: AppColors.featureCard,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
            ],
          ),
        ),
      ),
    );

    // The status is checked again on the next tap, so no restart is needed.
    if (openSettings == true) await openAppSettings();
  }

  // Remove the photo from the screen. The saved photo is deleted on Save.
  void _deletePhoto() {
    if (!_hasPhoto || _saving || _photoBusy) return;

    setState(() {
      _pendingPhoto = null;
      _pendingPhotoBytes = null;
      // Only a saved photo needs to be deleted. A photo picked just now was
      // never uploaded.
      _pendingDelete = _uploadedProfileImage != null;
    });
  }

  // Convert photo errors into friendly messages.
  // Technical details (HTTP status, server codes) are never shown.
  String _profilePhotoError(S s, ProfileImageException error) {
    return switch (error.code) {
      ProfileImageErrorCode.unauthenticated ||
      ProfileImageErrorCode.unauthorized => s.errProfilePhotoAuth,
      ProfileImageErrorCode.emailNotVerified => s.errProfilePhotoVerification,
      ProfileImageErrorCode.unreadableImage => s.errImageRead,
      ProfileImageErrorCode.unsupportedImage => s.errProfilePhotoType,
      ProfileImageErrorCode.imageTooLarge => s.errProfilePhotoSize,
      ProfileImageErrorCode.network => s.errNetwork,
      ProfileImageErrorCode.rateLimited => s.errProfilePhotoRateLimit,
      ProfileImageErrorCode.metadata => s.errProfilePhotoSave,
      ProfileImageErrorCode.server ||
      ProfileImageErrorCode.invalidResponse => s.errProfilePhotoServer,
    };
  }

  // Handle leaving the screen.
  Future<void> _leave() async {
    // Prevent leaving during an active operation.
    if (_saving || _photoBusy) return;

    // Leave directly if there are no unsaved changes.
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    // Ask before discarding unsaved changes.
    final discard = await _confirmDiscard();

    if (discard == true && mounted) Navigator.of(context).pop();
  }

  // Show a dialog to confirm discarding changes.
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
              // Show the discard confirmation title.
              Text(
                s.discardChangesTitle,
                textAlign: TextAlign.center,
                style: AppText.title(context).copyWith(fontSize: 22),
              ),

              const SizedBox(height: 24),

              // Continue editing without leaving.
              EthmarButton(
                label: s.keepEditing,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),

              const SizedBox(height: 12),

              // Discard changes and leave the screen.
              EthmarButton(
                label: s.discard,
                outlined: true,
                color: AppColors.featureCard,
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

    // Handle the back button without losing unsaved changes.
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
                // The same header as Profile: back button and centred title.
                EthmarCenteredHeader(title: s.editProfile),

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
                          // Display the profile photo and photo options.
                          _PhotoArea(
                            imageUrl: _uploadedProfileImage?.secureUrl,
                            localImage: _pendingPhotoBytes,
                            showDefault: _pendingDelete,
                            loading: _photoBusy || (_saving && _photoChanged),
                            onTakePhoto: () =>
                                _choosePhoto(ImageSource.camera),
                            onChooseFromGallery: () =>
                                _choosePhoto(ImageSource.gallery),
                            onDelete: _hasPhoto ? _deletePhoto : null,
                          ),

                          const SizedBox(height: 28),

                          // Username input field.
                          EthmarTextField(
                            label: s.username,
                            hint: s.usernameHint,
                            enabled: !_saving && !_photoBusy,
                            controller: _username,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            inputFormatters: Validators.usernameFormatters,
                            validator: (v) => Validators.username(v, s),
                            onSubmitted: _saving || _photoBusy
                                ? null
                                : (_) => _save(),
                          ),

                          const SizedBox(height: 28),

                          // Button to save username changes.
                          EthmarButton(
                            label: s.save,
                            loading: _saving,
                            onPressed: _saving || _photoBusy ? null : _save,
                          ),

                          const SizedBox(height: 12),

                          // Button to cancel editing.
                          EthmarButton(
                            label: s.cancel,
                            outlined: true,
                            color: AppColors.featureCard,
                            textColor: AppColors.textPrimary,
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

// Display the profile photo and photo action buttons.
class _PhotoArea extends StatelessWidget {
  const _PhotoArea({
    required this.imageUrl,
    required this.localImage,
    required this.showDefault,
    required this.loading,
    required this.onTakePhoto,
    required this.onChooseFromGallery,
    required this.onDelete,
  });

  final String? imageUrl;
  final Uint8List? localImage;
  final bool showDefault;
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
            // The current photo or default avatar, in a green ring like on Profile.
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: AppColors.forest,
                shape: BoxShape.circle,
              ),
              child: UserAvatar(
                size: 96,
                imageUrl: imageUrl,
                localImage: localImage,
                showDefault: showDefault,
              ),
            ),

            // Show loading over the avatar during photo operations.
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

            // Camera button on the avatar.
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

        // Display camera, gallery, and delete options.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            // Take a new photo using the camera.
            _PhotoPill(
              icon: Icons.photo_camera_outlined,
              label: s.takePhoto,
              onTap: loading ? null : onTakePhoto,
            ),

            // Choose a photo from the gallery.
            _PhotoPill(
              icon: Icons.photo_library_outlined,
              label: s.chooseFromGallery,
              onTap: loading ? null : onChooseFromGallery,
            ),

            // Show the delete option only when a photo exists.
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

// Build a small button for profile photo actions.
class _PhotoPill extends StatelessWidget {
  const _PhotoPill({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // A rounded rectangle in the Home green, like the app's other buttons.
    return Material(
      color: AppColors.featureCard,
      shape: const RoundedRectangleBorder(borderRadius: kControlRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: AppColors.forest),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppText.label(context)
                    .copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}