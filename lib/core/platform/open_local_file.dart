/// Opens a decrypted attachment with the OS default / "Open with" UI.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.nucleus.nucleus/open_file');

/// Returns an error message on failure, or `null` on success.
Future<String?> openLocalFile({
  required String path,
  required String mimeType,
}) async {
  if (kIsWeb) {
    return 'Opening files is not supported on web.';
  }
  if (Platform.isAndroid || Platform.isIOS) {
    final message = await _channel.invokeMethod<String?>('open', {
      'path': path,
      'mimeType': mimeType,
    });
    return message;
  }
  if (Platform.isWindows) {
    final exitCode = await Process.run('cmd', ['/c', 'start', '', path]);
    return exitCode.exitCode == 0 ? null : 'Could not open file';
  }
  if (Platform.isMacOS) {
    final exitCode = await Process.run('open', [path]);
    return exitCode.exitCode == 0 ? null : 'Could not open file';
  }
  if (Platform.isLinux) {
    final exitCode = await Process.run('xdg-open', [path]);
    return exitCode.exitCode == 0 ? null : 'Could not open file';
  }
  return 'Unsupported platform';
}
