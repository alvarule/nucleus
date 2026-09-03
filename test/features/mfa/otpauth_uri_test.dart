import 'package:flutter_test/flutter_test.dart';
import 'package:nucleus/features/mfa/domain/otpauth_uri.dart';

void main() {
  test('parses issuer:account from otpauth host=totp path', () {
    final parsed = OtpAuthUri.tryParse(
      'otpauth://totp/GitHub:user@example.com?secret=JBSWY3DPEHPK3PXP',
    );
    expect(parsed, isNotNull);
    expect(parsed!.issuer, 'GitHub');
    expect(parsed.accountName, 'user@example.com');
    expect(parsed.secret, 'JBSWY3DPEHPK3PXP');
  });

  test('parses account-only path with issuer query', () {
    final parsed = OtpAuthUri.tryParse(
      'otpauth://totp/user@x.com?secret=ABC&issuer=Google',
    );
    expect(parsed, isNotNull);
    expect(parsed!.issuer, 'Google');
    expect(parsed.accountName, 'user@x.com');
  });

  test('parses name query when path empty', () {
    final parsed = OtpAuthUri.tryParse(
      'otpauth://totp?secret=ABC&issuer=GitHub&name=user@x.com',
    );
    expect(parsed, isNotNull);
    expect(parsed!.accountName, 'user@x.com');
    expect(parsed.issuer, 'GitHub');
  });
}
