/// Heuristic strength scoring and a small common-password denylist.
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
  PasswordHealthResult evaluate(
    String password, {
    bool reused = false,
  }) {
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
