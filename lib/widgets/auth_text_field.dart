import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.hintText,
    this.icon,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.hintColor = AppColors.inputText,
    this.contentPadding,
    this.prefixIconSize = 22,
    this.uppercaseLabel = true,
    this.enabled = true,
  });

  final String label;
  final String hintText;
  final IconData? icon;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final Color hintColor;
  final EdgeInsets? contentPadding;
  final double prefixIconSize;
  final bool uppercaseLabel;
  final bool enabled;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.uppercaseLabel ? widget.label.toUpperCase() : widget.label,
          style: AppTypography.label,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          obscureText: _isObscured,
          textInputAction: widget.textInputAction,
          cursorColor: AppColors.darkBlue,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.inputText),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppTypography.bodyLarge.copyWith(
              color: widget.hintColor,
            ),
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding:
                widget.contentPadding ??
                EdgeInsets.fromLTRB(48, 16, widget.obscureText ? 48 : 16, 16),
            prefixIcon: widget.icon == null
                ? null
                : Icon(
                    widget.icon,
                    color: AppColors.bodyText,
                    size: widget.prefixIconSize,
                  ),
            prefixIconConstraints: widget.icon == null
                ? null
                : const BoxConstraints(minWidth: 48, minHeight: 56),
            suffixIcon: widget.obscureText
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        _isObscured = !_isObscured;
                      });
                    },
                    icon: Icon(
                      _isObscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.bodyText,
                      size: 22,
                    ),
                    tooltip: _isObscured ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 56,
            ),
            border: _fieldBorder,
            enabledBorder: _fieldBorder,
            focusedBorder: _fieldBorder.copyWith(
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static final OutlineInputBorder _fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.border),
  );
}
