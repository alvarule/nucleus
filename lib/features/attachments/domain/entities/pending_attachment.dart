/// File picked before a vault item row exists (create flow).
import 'dart:typed_data';

class PendingAttachment {
  const PendingAttachment({
    required this.filename,
    required this.bytes,
    required this.mimeType,
  });

  final String filename;
  final Uint8List bytes;
  final String mimeType;
}
