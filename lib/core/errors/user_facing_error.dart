/// Maps thrown errors to short UI copy, with warm offline messaging when needed.
import 'dart:io';

import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/core/errors/offline_messages.dart';
import 'package:nucleus/core/network/connectivity_service.dart';

/// True when [error] (or its [AppException.cause]) looks like a transport failure.
bool isNetworkError(Object error) {
  if (error is OfflineException) return true;
  if (error is SocketException) return true;
  if (error is HttpException) return true;
  if (error is IOException && error is! FileSystemException) return true;

  final text = error.toString().toLowerCase();
  const patterns = <String>[
    'socketexception',
    'clientexception',
    'failed host lookup',
    'network is unreachable',
    'connection refused',
    'connection reset',
    'connection timed out',
    'no address associated',
    'network error',
    'handshake exception',
    'software caused connection abort',
    'connection closed',
  ];
  if (patterns.any(text.contains)) return true;

  if (error is AppException && error.cause != null) {
    return isNetworkError(error.cause!);
  }
  return false;
}

/// Throws [OfflineException] with a random friendly line when offline.
Future<void> ensureOnline(ConnectivityService connectivity) async {
  if (!await connectivity.hasConnection()) {
    throw OfflineException(randomOfflineMessage());
  }
}

/// User-facing message for snackbars and form error text.
Future<String> userFacingErrorMessage(
  ConnectivityService connectivity,
  Object error,
) async {
  if (error is OfflineException) return error.message;

  if (!await connectivity.hasConnection()) {
    return randomOfflineMessage();
  }
  if (isNetworkError(error)) {
    return randomOfflineMessage();
  }
  if (error is AppException) return error.message;
  return error.toString();
}
