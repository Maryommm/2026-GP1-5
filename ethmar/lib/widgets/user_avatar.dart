import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/profile_image_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Shows the profile photo or the user's initial.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.username,
    this.size = 44,
    this.imageUrl,
  });

  final String username;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    // Use the provided image URL when available.
    final explicitUrl = imageUrl;
    if (explicitUrl != null) {
      return _image(explicitUrl, _fallback(context));
    }

    // Load image metadata only for a verified Firebase user.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) return _fallback(context);

    // Listen for changes to the user's saved profile image.
    return StreamBuilder<UploadedProfileImage?>(
      stream: profileImageMetadataStore.watch(user.uid),
      builder: (context, snapshot) {
        final savedUrl = snapshot.data?.secureUrl;
        return savedUrl == null
            ? _fallback(context)
            : _image(savedUrl, _fallback(context));
      },
    );
  }

  // Display the profile image with a fallback if loading fails.
  Widget _image(String url, Widget fallback) {
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  // Show the user's initial or a default person icon.
  Widget _fallback(BuildContext context) {
    final initial = username.isEmpty
        ? ''
        : username.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.forestTint,
        shape: BoxShape.circle,
      ),
      child: initial.isEmpty
          ? Icon(
              Icons.person_rounded,
              size: size * 0.5,
              color: AppColors.forest,
            )
          : Text(
              initial,
              style: AppText.label(context)
                  .copyWith(fontSize: size * 0.4, fontWeight: FontWeight.w700),
            ),
    );
  }
}