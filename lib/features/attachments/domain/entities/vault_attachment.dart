/// Encrypted file metadata row linked to a vault item.
import 'package:equatable/equatable.dart';

class VaultAttachment extends Equatable {
  const VaultAttachment({
    required this.id,
    required this.userId,
    required this.vaultItemId,
    required this.storageRoot,
    required this.originalFilename,
    required this.mimeType,
    required this.sizeBytes,
    required this.chunkCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String vaultItemId;
  final String storageRoot;
  final String originalFilename;
  final String mimeType;
  final int sizeBytes;
  final int chunkCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, vaultItemId, originalFilename, sizeBytes];
}
