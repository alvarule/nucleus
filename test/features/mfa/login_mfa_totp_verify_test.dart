import 'package:flutter_test/flutter_test.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/features/mfa/data/login_mfa_service.dart';
import 'package:otp/otp.dart';

/// Minimal crypto stub — only [verifyPlaintextTotp] is under test.
class _StubCrypto extends VaultCryptoService {
  _StubCrypto() : super();
}

void main() {
  late LoginMfaService service;

  setUp(() {
    service = LoginMfaService(_StubCrypto());
  });

  test('verify accepts code from the previous TOTP interval', () {
    const secret = 'JBSWY3DPEHPK3PXP';
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final prevStep = (nowSec ~/ 30) - 1;
    final prevMs = prevStep * 30 * 1000;
    final prevCode = OTP.generateTOTPCodeString(
      secret,
      prevMs,
      length: 6,
      interval: 30,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );

    expect(
      service.verifyPlaintextTotp(secret: secret, sixDigitCode: prevCode),
      isTrue,
    );
  });

  test('verify accepts code from submit time after period rolled during delay', () {
    const secret = 'JBSWY3DPEHPK3PXP';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final submitStep = (nowMs ~/ 1000) ~/ 30 - 1;
    final submitMs = submitStep * 30 * 1000;
    final codeAtSubmit = OTP.generateTOTPCodeString(
      secret,
      submitMs,
      length: 6,
      interval: 30,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );

    expect(
      service.verifyPlaintextTotp(
        secret: secret,
        sixDigitCode: codeAtSubmit,
        submittedAtMs: submitMs,
      ),
      isTrue,
    );
  });

  test('verify rejects wrong code', () {
    expect(
      service.verifyPlaintextTotp(
        secret: 'JBSWY3DPEHPK3PXP',
        sixDigitCode: '000000',
      ),
      isFalse,
    );
  });
}
