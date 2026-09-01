import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/core/errors/offline_messages.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';

void main() {
  test('randomOfflineMessage returns a known friendly line', () {
    final message = randomOfflineMessage();
    expect(offlineMessages, contains(message));
  });

  test('isNetworkError detects socket and host lookup failures', () {
    expect(isNetworkError(const SocketException('Failed host lookup')), isTrue);
    expect(
      isNetworkError(
        const AuthFailure('x', cause: SocketException('Connection refused')),
      ),
      isTrue,
    );
    expect(isNetworkError(const AuthFailure('Invalid email')), isFalse);
    expect(isNetworkError(const OfflineException('offline')), isTrue);
  });
}
