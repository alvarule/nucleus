/// Parses `otpauth://` URIs from authenticator QR codes into issuer, account, secret.
class OtpAuthUri {
  const OtpAuthUri({
    required this.secret,
    required this.issuer,
    required this.accountName,
  });

  final String secret;
  final String issuer;
  final String accountName;

  /// Returns null when the string is not a TOTP/HOTP otpauth URI with a secret.
  static OtpAuthUri? tryParse(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.toLowerCase().startsWith('otpauth://')) return null;
    final uri = Uri.parse(trimmed);
    final secret = uri.queryParameters['secret']?.trim() ?? '';
    if (secret.isEmpty) return null;

    var issuer = uri.queryParameters['issuer']?.trim() ?? '';
    var accountName = '';

    final label = _labelFromUri(uri);
    if (label.isNotEmpty) {
      final colon = label.indexOf(':');
      if (colon >= 0) {
        final pathIssuer = label.substring(0, colon).trim();
        accountName = label.substring(colon + 1).trim();
        if (issuer.isEmpty) issuer = pathIssuer;
      } else {
        accountName = label.trim();
      }
    }

    if (accountName.isEmpty) {
      accountName = _firstQuery(
        uri,
        ['name', 'email', 'account', 'username'],
      );
    }

    return OtpAuthUri(
      secret: secret,
      issuer: issuer,
      accountName: accountName,
    );
  }

  /// Label lives in the path for `otpauth://totp/Issuer:account` (host = totp).
  static String _labelFromUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'totp' || host == 'hotp') {
      final path = uri.path;
      if (path.length > 1) {
        return Uri.decodeComponent(path.startsWith('/') ? path.substring(1) : path);
      }
      return '';
    }

    if (uri.pathSegments.isEmpty) return '';

    if (uri.pathSegments.length >= 2) {
      return Uri.decodeComponent(uri.pathSegments.last);
    }

    final only = uri.pathSegments.first;
    if (only == 'totp' || only == 'hotp') return '';
    return Uri.decodeComponent(only);
  }

  static String _firstQuery(Uri uri, List<String> keys) {
    for (final key in keys) {
      final v = uri.queryParameters[key]?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return '';
  }
}
