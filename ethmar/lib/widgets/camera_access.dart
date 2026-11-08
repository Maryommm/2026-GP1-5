import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'ethmar_buttons.dart';

/// Makes sure the camera can be used, the same way as on Edit Profile:
/// Android's own prompt when it may still ask, and a dialog offering the
/// app's settings only when it won't. A plain "Don't allow" is respected
/// quietly. True when the camera may be opened.
Future<bool> ensureCameraAccess(BuildContext context) async {
  var status = await Permission.camera.status;
  if (status.isGranted) return true;

  if (!status.isPermanentlyDenied && !status.isRestricted) {
    status = await Permission.camera.request();
    if (status.isGranted) return true;
  }

  if ((status.isPermanentlyDenied || status.isRestricted) && context.mounted) {
    await showCameraSettingsDialog(context);
  }
  return false;
}

/// Explains that camera access is off and offers to open the settings.
Future<void> showCameraSettingsDialog(BuildContext context) async {
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
              style: AppText.title(dialogContext).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              s.cameraAccessBody,
              textAlign: TextAlign.center,
              style: AppText.body(dialogContext),
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
