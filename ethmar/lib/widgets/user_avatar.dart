import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Round avatar with the first letter of the username.
/// There are no profile pictures yet, so the letter stands in for one.
/// Used small on Home and large on Profile.
// TODO(profile-photo): load the user's saved photo (after login / on app
//   start) and show it here on Home, Profile and Edit Profile; keep the
//   initial as the fallback.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.username, this.size = 44});
  final String username;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial =
        username.isEmpty ? '' : username.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.forestTint,
        shape: BoxShape.circle,
      ),
      child: initial.isEmpty
          ? Icon(Icons.person_rounded,
              size: size * 0.5, color: AppColors.forest)
          : Text(
              initial,
              style: AppText.label(context).copyWith(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
