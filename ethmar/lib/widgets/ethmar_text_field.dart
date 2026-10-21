import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'ethmar_buttons.dart';

/// Label above a plain white rounded field, with friendly error text below.
///
/// Errors don't show while the user is typing: the field checks itself
/// two seconds after they stop. An empty field only shows its error when
/// the screen checks the whole form (e.g. the "Log in" button).
class EthmarTextField extends StatefulWidget {
  const EthmarTextField({
    super.key,
    required this.label,
    required this.hint,
    this.enabled = true,
    this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.isPassword = false,
    this.autofillHints,
    this.forceLtr = false,
    this.onSubmitted,
    this.fieldKey,
    this.inputFormatters,
    this.suffixIcon,
  });

  final String label;
  final String hint;
  final bool enabled;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool isPassword;
  final Iterable<String>? autofillHints;

  /// Emails and passwords are always typed left-to-right, even in Arabic.
  final bool forceLtr;
  final ValueChanged<String>? onSubmitted;

  /// Lets a screen validate just this field (e.g. the "Verify email" link).
  final GlobalKey<FormFieldState<String>>? fieldKey;

  /// Rules applied while typing, e.g. a length limit.
  final List<TextInputFormatter>? inputFormatters;

  /// Small status icon at the end of the field, e.g. "checking" or "ok".
  /// Password fields always show their show/hide toggle instead.
  final Widget? suffixIcon;

  @override
  State<EthmarTextField> createState() => _EthmarTextFieldState();
}

class _EthmarTextFieldState extends State<EthmarTextField> {
  bool _obscure = true;

  // How long to wait after the last key press before checking the field.
  static const _checkDelay = Duration(seconds: 2);
  Timer? _checkTimer;

  // Lets this field check itself when the screen didn't pass a [fieldKey].
  final _ownKey = GlobalKey<FormFieldState<String>>();
  GlobalKey<FormFieldState<String>> get _key => widget.fieldKey ?? _ownKey;

  // Which kind of check is running (see [_validate]).
  bool _hiding = false;
  bool _liveCheck = false;

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  // Wraps the screen's validator:
  // - While typing (_hiding), show no error.
  // - Two seconds after typing (_liveCheck), show errors, except "empty".
  // - Any other time it's the screen checking the form (a button), so run
  //   the full check, empty field included.
  String? _validate(String? value) {
    final validator = widget.validator;
    if (validator == null || _hiding) return null;
    if (_liveCheck) {
      return (value ?? '').trim().isEmpty ? null : validator(value);
    }
    // The button's result stays on screen until the user types again.
    _checkTimer?.cancel();
    return validator(value);
  }

  void _onChanged(String _) {
    if (widget.validator == null) return;
    _checkTimer?.cancel();
    // Hide the current error while the user fixes it.
    _hiding = true;
    _key.currentState?.validate();
    _hiding = false;
    _checkTimer = Timer(_checkDelay, () {
      if (!mounted) return;
      _liveCheck = true;
      _key.currentState?.validate();
      _liveCheck = false;
    });
  }

  static InputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: kControlRadius,
        borderSide: BorderSide(color: c, width: w),
      );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 8),
          child: Text(widget.label, style: AppText.label(context)),
        ),
        TextFormField(
          key: _key,
          enabled: widget.enabled,
          controller: widget.controller,
          validator: _validate,
          onChanged: _onChanged,
          inputFormatters: widget.inputFormatters,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.isPassword && _obscure,
          autofillHints: widget.autofillHints,
          onFieldSubmitted: widget.onSubmitted,
          textDirection: widget.forceLtr ? TextDirection.ltr : null,
          style: AppText.body(context, color: AppColors.textPrimary).copyWith(fontSize: 16),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintTextDirection: widget.forceLtr ? TextDirection.ltr : null,
            // textSecondary keeps the hint readable (AA) while staying
            // lighter than the forest-coloured typed value.
            hintStyle: AppText.body(context, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsetsDirectional.fromSTEB(18, 17, 12, 17),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscure ? s.showPassword : s.hidePassword,
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  )
                : widget.suffixIcon,
            errorStyle: AppText.small(context, color: AppColors.error),
            // Room for a heading and a few bullet points.
            errorMaxLines: 6,
            disabledBorder: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.forest, 1.6),
            errorBorder: _border(AppColors.error),
            focusedErrorBorder: _border(AppColors.error, 1.6),
          ),
        ),
      ],
    );
  }
}
