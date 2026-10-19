import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/profile_image_service.dart';
import '../theme/app_colors.dart';

/// Shows the profile photo, or the Ethmar default avatar when there is none.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.size = 44, this.imageUrl});

  static const defaultAvatar = 'assets/images/ethmar_default_avatar.png';

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

  // The Ethmar default avatar, on the feature-card green while it loads.
  Widget _fallback(BuildContext context) {
    // Decode the large image at the size it is shown.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: AppColors.featureCard,
          child: Image.asset(
            defaultAvatar,
            fit: BoxFit.cover,
            cacheWidth: pixels,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
