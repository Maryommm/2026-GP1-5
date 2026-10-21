import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_logo.dart';
import '../widgets/page_routes.dart';
import 'splash_screen.dart';

/// Shown when Firebase could not start. Uses a generic message only, so no
/// error details or project configuration ever reach the screen.
class StartupErrorScreen extends StatefulWidget {
  const StartupErrorScreen({super.key, required this.retry});

  /// Tries to start Firebase again. Returns true on success.
  final Future<bool> Function() retry;

  @override
  State<StartupErrorScreen> createState() => _StartupErrorScreenState();
}

class _StartupErrorScreenState extends State<StartupErrorScreen> {
  bool _retrying = false;

  Future<void> _onRetry() async {
    setState(() => _retrying = true);
    final ok = await widget.retry();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(fadeRoute(const SplashScreen()));
    } else {
      setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EthmarLogo(width: 110),
              const SizedBox(height: 32),
              Text(
                s.startupErrorTitle,
                style: AppText.title(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                s.startupErrorBody,
                style: AppText.body(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              EthmarButton(
                label: s.tryAgain,
                loading: _retrying,
                onPressed: _retrying ? null : _onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
