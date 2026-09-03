/// Six-box OTP-style input for authenticator codes (App Login MFA flows).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/mfa/domain/login_mfa_validation.dart';

class MfaOtpCodeField extends StatefulWidget {
  const MfaOtpCodeField({
    super.key,
    required this.controller,
    this.label = 'Authenticator code',
    this.errorText,
    this.enabled = true,
    this.onCompleted,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onCompleted;

  static const _length = 6;

  @override
  State<MfaOtpCodeField> createState() => _MfaOtpCodeFieldState();
}

class _MfaOtpCodeFieldState extends State<MfaOtpCodeField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    if (text.length == MfaOtpCodeField._length) {
      widget.onCompleted?.call(text);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final digits = widget.controller.text;
    final focused = _focus.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: scale.fontSm,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: scale.sm),
        GestureDetector(
          onTap: widget.enabled ? () => _focus.requestFocus() : null,
          child: Stack(
            children: [
              Row(
                children: List.generate(MfaOtpCodeField._length, (i) {
                  final char = i < digits.length ? digits[i] : '';
                  final isActive =
                      focused && i == digits.length &&
                          digits.length < MfaOtpCodeField._length;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i < MfaOtpCodeField._length - 1 ? scale.xs : 0,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        height: scale.s(52),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(scale.radiusSm),
                          border: Border.all(
                            color: widget.errorText != null
                                ? colors.danger
                                : (isActive || char.isNotEmpty
                                    ? colors.primary
                                    : colors.border),
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: char.isNotEmpty
                            ? Text(
                                char,
                                style: TextStyle(
                                  fontSize: scale.fontXl,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              )
                            : isActive
                                ? Container(
                                    width: scale.s(2),
                                    height: scale.s(22),
                                    color: colors.primary,
                                  )
                                : null,
                      ),
                    ),
                  );
                }),
              ),
              Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  maxLength: MfaOtpCodeField._length,
                  inputFormatters: mfaAuthenticatorInputFormatters(),
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: EdgeInsets.only(top: scale.sm),
            child: Text(
              widget.errorText!,
              style: TextStyle(
                color: colors.danger,
                fontSize: scale.fontSm,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
