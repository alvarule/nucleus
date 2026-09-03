/// Shared field validation for App Login MFA flows.
import 'package:flutter/services.dart';
String? mfaMasterPasswordFieldError(String value) {
  if (value.trim().isEmpty) return 'Enter your master password';
  return null;
}

String? mfaAuthenticatorCodeFieldError(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Enter your authenticator code';
  if (trimmed.length != 6) return 'Enter a 6-digit code';
  return null;
}

String? mfaSignInCodeFieldError(String value, {required bool backupMode}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Enter a code';
  if (!backupMode && trimmed.length != 6) {
    return 'Enter a 6-digit code';
  }
  return null;
}

/// Digits-only TOTP field (6 characters).
List<TextInputFormatter> mfaAuthenticatorInputFormatters() => [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ];
