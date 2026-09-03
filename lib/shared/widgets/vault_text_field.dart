/// Styled text field used across auth, vault, and settings.
/// Optional [onBeforeReveal] gates unmasking when [enableObscureToggle] is on.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';

class VaultTextField extends StatefulWidget {
  const VaultTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.enableObscureToggle = false,
    this.onBeforeReveal,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLength,
    this.inputFormatters,
    this.hideMaxLengthCounter = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool obscureText;
  final bool enableObscureToggle;
  /// Called before revealing an obscured field. Return false to keep it hidden.
  final Future<bool> Function()? onBeforeReveal;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final String? prefixIcon;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool hideMaxLengthCounter;

  @override
  State<VaultTextField> createState() => _VaultTextFieldState();
}

class _VaultTextFieldState extends State<VaultTextField> {
  late bool _obscure;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant VaultTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enableObscureToggle &&
        oldWidget.obscureText != widget.obscureText) {
      _obscure = widget.obscureText;
    }
  }

  Future<void> _toggleObscure() async {
    if (_toggling) return;
    if (!_obscure) {
      setState(() => _obscure = true);
      return;
    }
    // Hide is always free; show may require biometric/password confirmation.
    final confirm = widget.onBeforeReveal;
    if (confirm != null) {
      _toggling = true;
      try {
        final ok = await confirm();
        if (!mounted || !ok) return;
        setState(() => _obscure = false);
      } finally {
        _toggling = false;
      }
      return;
    }
    setState(() => _obscure = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Scale.of(context);
    final obscure = widget.enableObscureToggle ? _obscure : widget.obscureText;

    final fieldIconSize = scale.iconSm;

    Widget? suffix = widget.suffix;
    if (suffix == null && widget.enableObscureToggle) {
      suffix = IconButton(
        onPressed: _toggleObscure,
        icon: AppIcon(
          obscure ? 'eye' : 'eye_off',
          size: fieldIconSize,
          color: colors.textSecondary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: scale.fontSm,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: scale.sm),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          validator: widget.validator,
          onChanged: widget.onChanged,
          maxLines: obscure ? 1 : widget.maxLines,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          style: TextStyle(color: colors.textPrimary, fontSize: scale.fontLg),
          decoration: InputDecoration(
            hintText: widget.hint,
            counterText: widget.hideMaxLengthCounter ? '' : null,
            prefixIconConstraints: BoxConstraints(
              minWidth: scale.s(48),
              minHeight: scale.s(48),
            ),
            prefixIcon: widget.prefixIcon == null
                ? null
                : SizedBox(
                    width: scale.s(48),
                    height: scale.s(48),
                    child: Center(
                      child: AppIcon(
                        widget.prefixIcon!,
                        size: fieldIconSize,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Full-width primary CTA with an inline loading spinner.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? SizedBox(
              height: Scale.of(context).s(22),
              width: Scale.of(context).s(22),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.onPrimary,
              ),
            )
          : Text(label),
    );
  }
}

/// Title-cases snake_case / spaced form labels: `account_no` → `Account No`.
String titleCaseLabel(String raw) {
  final spaced = raw.replaceAll('_', ' ').trim();
  if (spaced.isEmpty) return spaced;
  return spaced
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return word;
        if (word.length == 1) return word.toUpperCase();
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}
