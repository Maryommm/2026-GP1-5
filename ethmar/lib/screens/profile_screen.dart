import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart' show currentUsername;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart' show EthmarToastType, showEthmarToast;
import '../widgets/backgrounds.dart';
import '../widgets/centered_header.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/page_routes.dart';
import '../widgets/user_avatar.dart';
import 'about_screen.dart';
import 'contact_screen.dart';
import 'edit_profile_screen.dart';
import 'welcome_screen.dart';

// Display the user's profile, settings and the log out button.
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

  // Ask first, then log out only if the user confirms.
  Future<void> _confirmLogout() async {
    if (_loading) return;
    final confirmed = await _showLogoutDialog();
    if (confirmed == true) await _logout();
  }

  // Centred dialog over a dimmed background. Cancel, Back or tapping
  // outside all return null/false, so nothing happens.
  Future<bool?> _showLogoutDialog() {
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
                s.logOutConfirmTitle,
                textAlign: TextAlign.center,
                style: AppText.title(context).copyWith(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                s.logOutConfirmBody,
                textAlign: TextAlign.center,
                style: AppText.body(context),
              ),
              const SizedBox(height: 24),
              EthmarButton(
                label: s.logOut,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
              const SizedBox(height: 12),
              EthmarButton(
                label: s.cancel,
                outlined: true,
                textColor: AppColors.textPrimary,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
        type: EthmarToastType.error,
      );
    } finally {
      // Stop loading after logout finishes.
      if (mounted) setState(() => _loading = false);
    }
  }

  // Bottom sheet with the two languages. Closing it without a choice
  // keeps the current language.
  void _showLanguageSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => const _LanguageSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final user = FirebaseAuth.instance.currentUser;

    // The signed-in user's email and account creation date from Firebase.
    final email = user?.email ?? '';
    final created = user?.metadata.creationTime;

    // Update the profile UI when the username changes.
    return ValueListenableBuilder<String>(
      valueListenable: currentUsername,
      builder: (context, savedName, _) {
        final username = savedName.isEmpty ? widget.username : savedName;
        return PopScope(
          // Stay put while logging out.
          canPop: !_loading,
          child: Scaffold(
            body: LeafPrintBackground(
              image: 'assets/images/ethmar_profile_background.png',
              child: Column(
                children: [
                  EthmarCenteredHeader(
                    title: s.profile,
                    trailing: HeaderPillButton(
                      icon: Icons.edit_outlined,
                      label: s.edit,
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(riseRoute(
                              EditProfileScreen(username: username))),
                    ),
                  ),
                  Expanded(
                    child: ScrollConfiguration(
                      // Disable the stretch effect while scrolling.
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(overscroll: false),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          8,
                          24,
                          24 + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Entrance(
                              child: _UserInfo(
                                username: username,
                                email: email,
                                created: created,
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Entrance(
                              delay: Duration(milliseconds: 100),
                              child: _Stats(),
                            ),
                            const SizedBox(height: 24),
                            Entrance(
                              delay: const Duration(milliseconds: 130),
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(
                                    start: 8, bottom: 10),
                                child: Text(
                                  s.settingsTitle,
                                  style: AppText.title(context)
                                      .copyWith(fontSize: 20),
                                ),
                              ),
                            ),
                            Entrance(
                              delay: const Duration(milliseconds: 150),
                              child: _SettingsCard(
                                items: [
                                  _SettingsItem(
                                    icon: Icons.language_rounded,
                                    label: s.settingsLanguage,
                                    value: appLocale.value.languageCode == 'ar'
                                        ? s.languageArabic
                                        : s.languageEnglish,
                                    onTap: _loading ? null : _showLanguageSheet,
                                  ),
                                  _SettingsItem(
                                    icon: Icons.info_outline_rounded,
                                    label: s.aboutEthmar,
                                    onTap: _loading
                                        ? null
                                        : () => Navigator.of(context)
                                            .push(riseRoute(const AboutScreen())),
                                  ),
                                  _SettingsItem(
                                    icon: Icons.mail_outline_rounded,
                                    label: s.contactEthmar,
                                    onTap: _loading
                                        ? null
                                        : () => Navigator.of(context).push(
                                            riseRoute(const ContactScreen())),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                            Entrance(
                              delay: const Duration(milliseconds: 200),
                              child: _LogOutButton(
                                label: s.logOut,
                                loading: _loading,
                                onPressed: _confirmLogout,
                              ),
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
        );
      },
    );
  }
}

// Avatar, username, member-since date and email, centred.
class _UserInfo extends StatelessWidget {
  const _UserInfo({
    required this.username,
    required this.email,
    required this.created,
  });
  final String username;
  final String email;
  final DateTime? created;

  // Same size as on Edit Profile, so the photo doesn't jump between them.
  static const _avatarSize = 96.0;
  static const _ring = 5.0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final date = created;
    return Column(
      children: [
        // The saved profile photo, or the Ethmar default avatar, in a
        // forest-green ring.
        Container(
          padding: const EdgeInsets.all(_ring),
          decoration: const BoxDecoration(
            color: AppColors.forest,
            shape: BoxShape.circle,
          ),
          child: const UserAvatar(size: _avatarSize),
        ),
        const SizedBox(height: 12),

        // The user's saved username.
        Semantics(
          label: s.username,
          child: Container(
            constraints: const BoxConstraints(minHeight: 41),
            alignment: Alignment.center,
            child: Text(
              username.isEmpty ? s.homeFriend : username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 26),
            ),
          ),
        ),

        // When the account was created, e.g. "Member since October 2026".
        if (date != null) ...[
          const SizedBox(height: 4),
          _InfoRow(
            text: s.memberSince(MaterialLocalizations.of(context)
                .formatMonthYear(date.toLocal())),
            style: AppText.body(context)
                .copyWith(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],

        // The registered email, quiet and always left-to-right.
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          _InfoRow(
            icon: Icons.mail_outline_rounded,
            text: email,
            textDirection: TextDirection.ltr,
            style: AppText.small(context).copyWith(fontSize: 13),
          ),
        ],
      ],
    );
  }
}

// Two balanced cards: plants and rank.
class _Stats extends StatelessWidget {
  const _Stats();

  // TODO(stats): Temporary fixed values for this stage. Connect to the
  //   user's real plants and leaderboard rank once they are stored.
  static const _plantCount = '0';
  static const _rank = '—';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return IntrinsicHeight(
      child: Row(
        // My Plants stays on the left and My Rank on the right in both
        // languages; text inside each card keeps the app's direction.
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatCard(
              image: 'assets/images/ethmar_plant_icon.png',
              imageSize: 32,
              color: AppColors.featureCard,
              value: _plantCount,
              label: s.statMyPlants,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              // The trophy image has more empty space around it, so it is
              // drawn a little larger to look the same size as the plant.
              image: 'assets/images/ethmar_rank_icon.png',
              imageSize: 36,
              color: AppColors.sunTint,
              value: _rank,
              label: s.statMyRank,
            ),
          ),
        ],
      ),
    );
  }
}

// Label centred on top; icon and value centred together below it.
// Display only: no tap, no chevron.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.image,
    required this.imageSize,
    required this.color,
    required this.value,
    required this.label,
  });
  final String image;
  final double imageSize;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Row 1: the label, centred (Arabic keeps its RTL direction).
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.small(context).copyWith(fontSize: 14),
            ),
            const SizedBox(height: 4),
            // Row 2: icon then value, one centred group, left-to-right
            // in both languages.
            Row(
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Image.asset(
                      image,
                      width: imageSize,
                      height: imageSize,
                      cacheWidth: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: AppText.label(context)
                          .copyWith(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// A small centred icon + text line under the username.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    this.icon,
    required this.text,
    required this.style,
    this.textDirection,
  });
  /// Optional small icon before the text.
  final IconData? icon;
  final String text;
  final TextStyle style;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: textDirection,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: textDirection,
            style: style,
          ),
        ),
      ],
    );
  }
}

// Soft peach outlined button with a log-out icon.
class _LogOutButton extends StatelessWidget {
  const _LogOutButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      enabled: !loading,
      child: Material(
        color: AppColors.coralTint,
        // Same rounded shape and border width as the language options.
        shape: RoundedRectangleBorder(
          borderRadius: kControlRadius,
          side: BorderSide(
            color: AppColors.coralDark.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onPressed,
          child: SizedBox(
            height: 52,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.coralDark,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Arrow points the reading way in Arabic too.
                        Transform.flip(
                          flipX: isRtl,
                          child: const Icon(
                            Icons.logout_rounded,
                            size: 20,
                            color: AppColors.coralDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label(
                              context,
                              color: AppColors.coralDark,
                            ).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsItem {
  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
}

// One white card holding the settings rows, with thin separators.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.items});
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.border,
              ),
            _SettingsRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.item});
  final _SettingsItem item;

  @override
  Widget build(BuildContext context) {
    final value = item.value;
    return InkWell(
      onTap: item.onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.featureCard,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 20, color: AppColors.forest),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: AppText.label(context)
                      .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(value, style: AppText.small(context)),
              ],
              const SizedBox(width: 4),
              // Flips automatically in Arabic.
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Arabic and English, with the current one marked.
class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final current = appLocale.value.languageCode;

    Widget option(String code, String label) {
      final selected = code == current;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected ? AppColors.featureCard : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: kControlRadius,
            side: BorderSide(
              color: selected ? AppColors.forest : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
              if (!selected) setAppLanguage(code);
            },
            child: Semantics(
              selected: selected,
              button: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: AppText.label(context).copyWith(
                            fontSize: 16,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: selected ? AppColors.forest : AppColors.textHint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.chooseLanguage,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 16),
            option('ar', s.languageArabic),
            option('en', s.languageEnglish),
          ],
        ),
      ),
    );
  }
}
