/// Vault item types, decrypted presentation model, and encrypted row shape.
import 'package:equatable/equatable.dart';
import 'package:nucleus/features/vault/domain/entities/vault_sync_mode.dart';

enum VaultItemType { password, bankAccount, atmCard, note, document }

/// Maps enum ↔ `vault_items.item_type` and UI labels/icons.
extension VaultItemTypeX on VaultItemType {
  String get dbValue => switch (this) {
        VaultItemType.password => 'password',
        VaultItemType.bankAccount => 'bank_account',
        VaultItemType.atmCard => 'atm_card',
        VaultItemType.note => 'note',
        VaultItemType.document => 'document',
      };

  String get label => switch (this) {
        VaultItemType.password => 'Password',
        VaultItemType.bankAccount => 'Bank account',
        VaultItemType.atmCard => 'ATM card',
        VaultItemType.note => 'Note',
        VaultItemType.document => 'Document',
      };

  String get icon => switch (this) {
        VaultItemType.password => 'lock',
        VaultItemType.bankAccount => 'bank',
        VaultItemType.atmCard => 'card',
        VaultItemType.note => 'note',
        VaultItemType.document => 'note',
      };

  static VaultItemType fromDb(String value) => switch (value) {
        'bank_account' => VaultItemType.bankAccount,
        'atm_card' => VaultItemType.atmCard,
        'note' => VaultItemType.note,
        'document' => VaultItemType.document,
        _ => VaultItemType.password,
      };
}

/// Decrypted vault item used in presentation after unlock.
class VaultItem extends Equatable {
  const VaultItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.fields,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.syncMode = VaultSyncMode.cloud,
  });

  final String id;
  final String userId;
  final VaultItemType type;
  final Map<String, dynamic> fields;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Null means Uncategorized. Not encrypted.
  final String? folderId;
  final VaultSyncMode syncMode;

  String get label => (fields['label'] as String?) ?? 'Untitled';

  /// Secondary line for vault list tiles. Notes show label only.
  String? get listSubtitle {
    switch (type) {
      case VaultItemType.password:
        final username = '${fields['username'] ?? ''}'.trim();
        return username.isEmpty ? null : username;
      case VaultItemType.bankAccount:
        return _endingWith(fields['account_no']);
      case VaultItemType.atmCard:
        return _endingWith(fields['card_no']);
      case VaultItemType.note:
        return null;
      case VaultItemType.document:
        return null;
    }
  }

  static String? _endingWith(dynamic raw) {
    final digits = '$raw'.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) {
      return 'Ending with ${digits.substring(digits.length - 4)}';
    }
    final text = '$raw'.trim();
    if (text.isEmpty) return null;
    final tail = text.length <= 4 ? text : text.substring(text.length - 4);
    return 'Ending with $tail';
  }

  VaultItem copyWith({
    Map<String, dynamic>? fields,
    String? folderId,
    bool clearFolderId = false,
    VaultSyncMode? syncMode,
  }) {
    return VaultItem(
      id: id,
      userId: userId,
      type: type,
      fields: fields ?? this.fields,
      createdAt: createdAt,
      updatedAt: updatedAt,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      syncMode: syncMode ?? this.syncMode,
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, type, fields, createdAt, updatedAt, folderId, syncMode];
}

/// Ciphertext row as stored in `vault_items` (unused by the repository today;
/// decrypt path maps rows directly to [VaultItem]).
class VaultItemRecord {
  const VaultItemRecord({
    required this.id,
    required this.userId,
    required this.itemType,
    required this.encryptedPayload,
    required this.nonce,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String itemType;
  final String encryptedPayload;
  final String nonce;
  final DateTime createdAt;
  final DateTime updatedAt;
}
