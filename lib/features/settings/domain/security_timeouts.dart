/// Auto-lock and reveal-grace options. A `null` duration means no timeout.
enum VaultAutoLockOption {
  thirtySeconds,
  oneMinute,
  fiveMinutes,
  fifteenMinutes,
  thirtyMinutes,
  whileUsingApp,
}

extension VaultAutoLockOptionX on VaultAutoLockOption {
  String get label => switch (this) {
        VaultAutoLockOption.thirtySeconds => '30 seconds',
        VaultAutoLockOption.oneMinute => '1 minute',
        VaultAutoLockOption.fiveMinutes => '5 minutes',
        VaultAutoLockOption.fifteenMinutes => '15 minutes',
        VaultAutoLockOption.thirtyMinutes => '30 minutes',
        VaultAutoLockOption.whileUsingApp => 'While using app',
      };

  String get description => switch (this) {
        VaultAutoLockOption.whileUsingApp =>
          'Never lock automatically — use Lock vault now',
        _ => 'Lock after $label of inactivity (includes time in background)',
      };

  /// `null` means never auto-lock while the app is in the foreground.
  Duration? get duration => switch (this) {
        VaultAutoLockOption.thirtySeconds => const Duration(seconds: 30),
        VaultAutoLockOption.oneMinute => const Duration(minutes: 1),
        VaultAutoLockOption.fiveMinutes => const Duration(minutes: 5),
        VaultAutoLockOption.fifteenMinutes => const Duration(minutes: 15),
        VaultAutoLockOption.thirtyMinutes => const Duration(minutes: 30),
        VaultAutoLockOption.whileUsingApp => null,
      };
}

/// How long reveal/copy can skip biometric/password after a successful gate.
enum RevealGraceOption {
  everyTime,
  thirtySeconds,
  oneMinute,
  twoMinutes,
  fiveMinutes,
}

extension RevealGraceOptionX on RevealGraceOption {
  String get label => switch (this) {
        RevealGraceOption.everyTime => 'Every time',
        RevealGraceOption.thirtySeconds => '30 seconds',
        RevealGraceOption.oneMinute => '1 minute',
        RevealGraceOption.twoMinutes => '2 minutes',
        RevealGraceOption.fiveMinutes => '5 minutes',
      };

  String get description => switch (this) {
        RevealGraceOption.everyTime =>
          'Ask for fingerprint or password on every reveal or copy',
        _ => 'Skip re-auth for $label after confirming once',
      };

  /// `null` means re-auth is required for every sensitive action.
  Duration? get duration => switch (this) {
        RevealGraceOption.everyTime => null,
        RevealGraceOption.thirtySeconds => const Duration(seconds: 30),
        RevealGraceOption.oneMinute => const Duration(minutes: 1),
        RevealGraceOption.twoMinutes => const Duration(minutes: 2),
        RevealGraceOption.fiveMinutes => const Duration(minutes: 5),
      };
}

/// Password age threshold for the Health tab "Old" filter.
enum PasswordAgeThresholdOption {
  ninetyDays,
  oneEightyDays,
}

extension PasswordAgeThresholdOptionX on PasswordAgeThresholdOption {
  String get label => switch (this) {
        PasswordAgeThresholdOption.ninetyDays => '90 days',
        PasswordAgeThresholdOption.oneEightyDays => '180 days',
      };

  String get description => switch (this) {
        PasswordAgeThresholdOption.ninetyDays =>
          'Flag passwords not changed in over 90 days',
        PasswordAgeThresholdOption.oneEightyDays =>
          'Flag passwords not changed in over 180 days',
      };

  int get days => switch (this) {
        PasswordAgeThresholdOption.ninetyDays => 90,
        PasswordAgeThresholdOption.oneEightyDays => 180,
      };
}

class SecurityTimeouts {
  const SecurityTimeouts({
    this.autoLock = VaultAutoLockOption.fiveMinutes,
    this.revealGrace = RevealGraceOption.twoMinutes,
    this.passwordAgeThreshold = PasswordAgeThresholdOption.ninetyDays,
  });

  final VaultAutoLockOption autoLock;
  final RevealGraceOption revealGrace;
  final PasswordAgeThresholdOption passwordAgeThreshold;

  SecurityTimeouts copyWith({
    VaultAutoLockOption? autoLock,
    RevealGraceOption? revealGrace,
    PasswordAgeThresholdOption? passwordAgeThreshold,
  }) {
    return SecurityTimeouts(
      autoLock: autoLock ?? this.autoLock,
      revealGrace: revealGrace ?? this.revealGrace,
      passwordAgeThreshold:
          passwordAgeThreshold ?? this.passwordAgeThreshold,
    );
  }
}
