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
import '../widgets/ethmar_logo.dart' show parseSvgPath;

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
                    child: _ContactCard(
                      icon: const Icon(
                        Icons.mail_outline_rounded,
                        size: 24,
                        color: AppColors.forest,
                      ),
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
                    delay: const Duration(milliseconds: 60),
                    child: _ContactCard(
                      icon: const _XLogo(size: 20),
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

/// The X (formerly Twitter) logo, drawn from X's official mark path.
class _XLogo extends StatelessWidget {
  const _XLogo({required this.size});
  final double size;

  // X's logo, viewBox 0 0 1200 1227.
  static final _path = parseSvgPath(
    'M714.163 519.284L1160.89 0H1055.03L667.137 450.887L357.328 0H0'
    'L468.492 681.821L0 1226.37H105.866L515.491 750.218L842.672 1226.37'
    'H1200L714.137 519.284H714.163Z'
    'M569.165 687.828L521.697 619.934L144.011 79.6944H306.615'
    'L611.412 515.685L658.88 583.579L1055.08 1150.3H892.476'
    'L569.165 687.854V687.828Z',
  );

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size * 1227 / 1200,
        child: CustomPaint(painter: _XLogoPainter(_path)),
      ),
    );
  }
}

class _XLogoPainter extends CustomPainter {
  const _XLogoPainter(this.path);
  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 1200, size.height / 1227);
    // evenOdd keeps the inner stroke of the X hollow, as in the logo.
    canvas.drawPath(
      path..fillType = PathFillType.evenOdd,
      Paint()..color = AppColors.textPrimary,
    );
  }

  @override
  bool shouldRepaint(_XLogoPainter old) => false;
}

// A tappable white card: icon, title and the address/handle.
class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final Widget icon;
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
                  child: icon,
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
