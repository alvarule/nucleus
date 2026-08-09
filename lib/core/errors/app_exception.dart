class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class AuthFailure extends AppException {
  const AuthFailure(super.message, {super.cause});
}

class CryptoException extends AppException {
  const CryptoException(super.message, {super.cause});
}

class VaultException extends AppException {
  const VaultException(super.message, {super.cause});
}
