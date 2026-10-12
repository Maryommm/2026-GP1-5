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

/// Profile: tinted header band with a back button, the avatar overlapping
/// it, then username, email and the stats area, and the account buttons.
/// Opened from the avatar on Home; it has no bottom bar.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.username = ''});
  final String username;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  bool _loading = false;

  // Same log out as before: sign out, then clear every screen so the
  // back button can't return to Home or Profile.
  Future<void> _logout() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        riseRoute(const WelcomeScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      showEthmarToast(
        context,
        S.of(context).errLogout,
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // The signed-in user's email comes straight from Firebase Auth.
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    // Rebuilds as soon as the username changes (e.g. after Edit Profile).
    return ValueListenableBuilder<String>(
      valueListenable: currentUsername,
      builder: (context, savedName, _) =>
          _buildPage(context, s, email, savedName.isEmpty ? widget.username : savedName),
    );
  }

  Widget _buildPage(
      BuildContext context, S s, String email, String username) {
    return Scaffold(
      body: LeafPrintBackground(
        child: ScrollConfiguration(
          // Keep normal scrolling, but no stretch when pulling past the edges.
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
                bottom: 24 + MediaQuery.paddingOf(context).bottom),
            child: Column(
              children: [
                _Header(username: username),
                const SizedBox(height: 12),
                Entrance(
                  child: Column(
                    children: [
                      Semantics(
                        label: s.username,
                        // Same reserved height in both languages, so the
                        // email and everything below don't move.
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
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        // Emails always read left-to-right, even in Arabic.
                        Text(
                          email,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: AppText.small(context),
                        ),
                      ],
                      const SizedBox(height: 16),
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
                        EthmarButton(
                          label: s.editProfile,
                          outlined: true,
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).push(riseRoute(
                                  EditProfileScreen(username: username))),
                        ),
                        const SizedBox(height: 12),
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

// ---------------------------------------------------------------------------
// Header: tinted band with the back button and the language chip in the
// opposite corner (they swap sides in Arabic), and the big avatar overlapping
// its bottom edge. The sand-coloured ring around the avatar gives the
// "cut-out" look from the sketch.
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.username});
  final String username;

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
          Container(
            height: bandHeight,
            decoration: const BoxDecoration(
              color: AppColors.forestTint,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
          ),
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
          // Language switch in the opposite corner, the same chip as Welcome.
          PositionedDirectional(
            top: top + 8,
            end: 16,
            child: const LanguageChip(),
          ),
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

// ---------------------------------------------------------------------------
// Stats area: plants and leaderboard, icon + value like the sketch.
// TEMP values until the real data exists:
//  * plants: 0 (empty state). Replace with the user's real plant count
//    once Virtual Farm / My Plants and plant storage are built.
//  * leaderboard: "—" (no rank yet). Replace with the user's real rank or
//    score once the Leaderboard feature is built.
// ---------------------------------------------------------------------------

class _Stats extends StatelessWidget {
  const _Stats();

  static const _plantCount = '0';
  static const _rank = '—';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Same order in both languages: plants first, then leaderboard.
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

/// One statistic: icon and value. [label] is read out by screen readers.
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
