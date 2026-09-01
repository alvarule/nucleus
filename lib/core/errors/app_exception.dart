/// Domain error types used across auth, crypto, and vault layers.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Thrown when the device has no usable internet connection.
class OfflineException extends AppException {
  const OfflineException(super.message, {super.cause});
}

/// Sign-in/sign-up/password-update failures with a user-facing [message].
class AuthFailure extends AppException {
  const AuthFailure(super.message, {super.cause});
}

/// DEK unwrap or profile-crypto failures.
class CryptoException extends AppException {
  const CryptoException(super.message, {super.cause});
}

/// Item encrypt/decrypt or repository failures.
class VaultException extends AppException {
  const VaultException(super.message, {super.cause});
}
