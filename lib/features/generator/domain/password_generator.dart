/// Local password generator and a heuristic health checker used by Health tab.
import 'dart:math';

class PasswordGenerator {
  PasswordGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  /// Guarantees at least one char from each selected set, then fills and shuffles.
  String generate({
    int length = 16,
    bool lower = true,
    bool upper = true,
    bool numbers = true,
    bool symbols = true,
  }) {
    final buffers = <String>[];
    if (lower) buffers.add('abcdefghijklmnopqrstuvwxyz');
    if (upper) buffers.add('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    if (numbers) buffers.add('0123456789');
    if (symbols) buffers.add(r'!@#$%^&*()-_=+[]{};:,.?/');
    if (buffers.isEmpty || length < 4) {
      throw ArgumentError('Select at least one character set and length >= 4');
    }
    final all = buffers.join();
    final chars = <String>[];
    for (final set in buffers) {
      chars.add(set[_random.nextInt(set.length)]);
    }
    while (chars.length < length) {
      chars.add(all[_random.nextInt(all.length)]);
    }
    chars.shuffle(_random);
    return chars.join();
  }
}

enum PasswordStrength { weak, fair, strong, excellent }

class PasswordHealthResult {
  const PasswordHealthResult({
    required this.strength,
    required this.score,
    required this.issues,
    required this.reused,
  });

  final PasswordStrength strength;
  final int score;
  final List<String> issues;
  final bool reused;
}

/// Heuristic strength/reuse scoring for the Health tab (not a breach checker).
class PasswordHealthChecker {
  /// Small denylist; not a comprehensive breach corpus.
  static const _common = {
    'password',
    '123456',
    '12345678',
    'qwerty',
    'abc123',
    'password1',
    '111111',
    '123123',
    'admin',
    'letmein',
    'welcome',
    'monkey',
    'login',
  };

  /// Scores length + charset; common passwords zero the score.
  /// [otherPasswords] is expected to be the vault's unique password set.
  PasswordHealthResult evaluate(String password, {Set<String> otherPasswords = const {}}) {
    final issues = <String>[];
    var score = 0;

    if (password.length >= 12) {
      score += 30;
    } else if (password.length >= 8) {
      score += 15;
      issues.add('Use at least 12 characters');
    } else {
      issues.add('Too short');
    }

    if (password.contains(RegExp(r'[a-z]'))) {
      score += 15;
    } else {
      issues.add('Add lowercase letters');
    }

    if (password.contains(RegExp(r'[A-Z]'))) {
      score += 15;
    } else {
      issues.add('Add uppercase letters');
    }

    if (password.contains(RegExp(r'[0-9]'))) {
      score += 15;
    } else {
      issues.add('Add numbers');
    }

    if (password.contains(RegExp(r'[^A-Za-z0-9]'))) {
      score += 15;
    } else {
      issues.add('Add special characters');
    }

    if (_common.contains(password.toLowerCase())) {
      score = 0;
      issues.add('Common password');
    }

    // With a Set, count-of-equals cannot exceed 1. Reuse is then inferred if
    // this password is in the set and the vault has more than one unique value.
    final reused = otherPasswords.where((p) => p == password).length > 1 ||
        (otherPasswords.contains(password) && otherPasswords.length > 1);
    if (reused) {
      score = (score - 25).clamp(0, 100);
      issues.add('Reused across vault');
    }

    final strength = score >= 80
        ? PasswordStrength.excellent
        : score >= 60
            ? PasswordStrength.strong
            : score >= 35
                ? PasswordStrength.fair
                : PasswordStrength.weak;

    return PasswordHealthResult(
      strength: strength,
      score: score.clamp(0, 100),
      issues: issues,
      reused: reused,
    );
  }
}
