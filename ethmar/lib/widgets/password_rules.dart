import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../screens/validators.dart' show PasswordRule, Validators;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The password rules as a list under the sign-up password field. Each rule
/// starts dim with a small dot, and turns green with a tick as soon as the
/// typed password follows it. The account can only be created once all of
/// them are green (see [Validators.newPassword]).
class PasswordRules extends StatelessWidget {
  const PasswordRules({super.key, required this.controller});

  /// The password field's controller; the list updates as the user types.
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final password = controller.text;
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.passwordRulesTitle,
                style: AppText.small(context).copyWith(fontSize: 13),
              ),
              const SizedBox(height: 4),
              for (final rule in PasswordRule.values)
                _Rule(
                  key: Key('passwordRule_${rule.name}'),
                  label: rule.label(s),
                  met: Validators.passwordRuleMet(rule, password),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({super.key, required this.label, required this.met});
  final String label;
  final bool met;

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    // Dim until followed: secondary text, a little faded.
    final colour = met
        ? AppColors.success
        : AppColors.textSecondary.withValues(alpha: 0.75);
    return Semantics(
      checked: met,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: AnimatedSwitcher(
                duration: _duration,
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: met
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey(true),
                        size: 18,
                        color: AppColors.success,
                      )
                    : Center(
                        key: const ValueKey(false),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colour,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: _duration,
                style: AppText.small(context, color: colour).copyWith(
                  fontSize: 13,
                  fontWeight: met ? FontWeight.w600 : FontWeight.w400,
                ),
                child: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
