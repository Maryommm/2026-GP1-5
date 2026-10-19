import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart' show EthmarToastType, showEthmarToast;
import '../widgets/backgrounds.dart';
import '../widgets/centered_header.dart';
import '../widgets/entrance.dart';

/// Contact Ethmar: a short intro and two cards (email and X).
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const supportEmail = 'ethmar.support@gmail.com';
  static const xHandle = '@EthmarApp';
  static const xUrl = 'https://x.com/EthmarApp';

  // Open [uri] outside the app. If nothing can open it, copy [fallback]
  // so the user can still reach us, and say so.
  static Future<void> _open(
    BuildContext context,
    Uri uri, {
    required String fallback,
    required String errorMessage,
  }) async {
    var opened = false;
    try {
      // The X app opens x.com links when installed, otherwise the browser.
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;

    await Clipboard.setData(ClipboardData(text: fallback));
    if (!context.mounted) return;
    showEthmarToast(context, errorMessage, type: EthmarToastType.info);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: LeafPrintBackground(
        child: Column(
          children: [
            EthmarCenteredHeader(title: s.contactEthmar),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  Entrance(
                    child: Text(
                      s.contactIntro,
                      textAlign: TextAlign.center,
                      style: AppText.body(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Entrance(
                    delay: const Duration(milliseconds: 100),
                    child: _ContactCard(
                      icon: Icons.mail_outline_rounded,
                      title: s.contactEmailTitle,
                      detail: supportEmail,
                      onTap: () => _open(
                        context,
                        Uri(scheme: 'mailto', path: supportEmail),
                        fallback: supportEmail,
                        errorMessage: s.errOpenEmail,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Entrance(
                    delay: const Duration(milliseconds: 160),
                    child: _ContactCard(
                      icon: Icons.alternate_email_rounded,
                      title: s.contactXTitle,
                      detail: xHandle,
                      onTap: () => _open(
                        context,
                        Uri.parse(xUrl),
                        fallback: xUrl,
                        errorMessage: s.errOpenLink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A tappable white card: icon, title and the address/handle.
class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.featureCard,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 24, color: AppColors.forest),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.label(context)
                            .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      // Addresses always read left-to-right.
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: AppText.small(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 20,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
