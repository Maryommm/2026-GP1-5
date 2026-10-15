import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart' show currentUsername;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart' show showEthmarToast;
import '../widgets/backgrounds.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/language_chip.dart';
import '../widgets/page_routes.dart';
import '../widgets/user_avatar.dart';
import 'edit_profile_screen.dart';
import 'welcome_screen.dart';

// Display the user's profile and account options.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.username = ''});
  final String username;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();

  // Track the logout loading state.
  bool _loading = false;

  // Sign out and return to the Welcome screen.
  Future<void> _logout() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      // Sign out from Firebase.
      await _authService.signOut();

      if (!mounted) return;

      // Clear previous screens to prevent returning after logout.
      Navigator.of(context).pushAndRemoveUntil(
        riseRoute(const WelcomeScreen()),
        (_) => false,
      );
    } catch (_) {
      // Show an error if logout fails.
      if (!mounted) return;
      showEthmarToast(
        context,
        S.of(context).errLogout,
        icon: Icons.error_outline_rounded,
      );
    } finally {
      // Stop loading after logout finishes.
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    // Get the signed-in user's email from Firebase.
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    // Update the profile UI when the username changes.
    return ValueListenableBuilder<String>(
      valueListenable: currentUsername,
      builder: (context, savedName, _) =>
          _buildPage(context, s, email, savedName.isEmpty ? widget.username : savedName),
    );
  }

  // Build the profile screen layout.
  Widget _buildPage(
      BuildContext context, S s, String email, String username) {
    return Scaffold(
      body: LeafPrintBackground(
        child: ScrollConfiguration(
          // Disable the stretch effect while scrolling.
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
                bottom: 24 + MediaQuery.paddingOf(context).bottom),
            child: Column(
              children: [
                // Show the profile header and avatar.
                _Header(username: username),

                const SizedBox(height: 12),

                Entrance(
                  child: Column(
                    children: [
                      // Display the user's username.
                      Semantics(
                        label: s.username,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 41),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            username.isEmpty ? s.homeFriend : username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppText.title(context),
                          ),
                        ),
                      ),

                      // Display the user's email if available.
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          email,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: AppText.small(context),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Show the user's plants and leaderboard stats.
                      const _Stats(),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Entrance(
                    delay: const Duration(milliseconds: 150),
                    child: Column(
                      children: [
                        // Button to open Edit Profile.
                        EthmarButton(
                          label: s.editProfile,
                          outlined: true,
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).push(riseRoute(
                                  EditProfileScreen(username: username))),
                        ),

                        const SizedBox(height: 12),

                        // Button to log out.
                        EthmarButton(
                          label: s.logOut,
                          outlined: true,
                          loading: _loading,
                          onPressed: _loading ? null : _logout,
                        ),
                      ],
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

// Build the profile header with the avatar and language button.
class _Header extends StatelessWidget {
  const _Header({required this.username});
  final String username;

  // Set the avatar size and border thickness.
  static const _avatarSize = 110.0;
  static const _ring = 6.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bandHeight = top + 120;
    const outer = _avatarSize + _ring * 2;

    return SizedBox(
      height: bandHeight + outer / 2,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Background color behind the avatar.
          Container(
            height: bandHeight,
            decoration: const BoxDecoration(
              color: AppColors.forestTint,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
          ),

          // Back button.
          PositionedDirectional(
            top: top + 8,
            start: 16,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: EthmarBackButton(tooltip: S.of(context).back),
            ),
          ),

          // Language switch button.
          PositionedDirectional(
            top: top + 8,
            end: 16,
            child: const LanguageChip(),
          ),

          // Display the user's avatar.
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(_ring),
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: UserAvatar(username: username, size: _avatarSize),
            ),
          ),
        ],
      ),
    );
  }
}

// Display the user's plant count and leaderboard rank.
class _Stats extends StatelessWidget {
  const _Stats();

  // Temporary values until real stats are available.
  static const _plantCount = '0';
  static const _rank = '—';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    // Keep the same stats order in both languages.
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        _StatItem(
          icon: Icons.yard_outlined,
          value: _plantCount,
          label: s.statPlants,
        ),
        const SizedBox(width: 48),
        _StatItem(
          icon: Icons.leaderboard_outlined,
          value: _rank,
          label: s.statRank,
        ),
      ],
    );
  }
}

// Display one statistic with its icon and value.
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Add a readable label for screen readers.
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          Icon(icon, size: 22, color: AppColors.forest),
          const SizedBox(width: 8),
          Text(
            value,
            style: AppText.label(context).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}