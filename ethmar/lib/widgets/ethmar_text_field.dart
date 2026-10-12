import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'ethmar_buttons.dart';

/// Label above a plain white rounded field, with friendly error text below.
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

  @override
  State<EthmarTextField> createState() => _EthmarTextFieldState();
}

class _EthmarTextFieldState extends State<EthmarTextField> {
  bool _obscure = true;

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
          key: widget.fieldKey,
          enabled: widget.enabled,
          controller: widget.controller,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.isPassword && _obscure,
          autofillHints: widget.autofillHints,
          onFieldSubmitted: widget.onSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          textDirection: widget.forceLtr ? TextDirection.ltr : null,
          style: AppText.body(context, color: AppColors.forest).copyWith(fontSize: 16),
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
                : null,
            errorStyle: AppText.small(context, color: AppColors.error),
            errorMaxLines: 3,
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
