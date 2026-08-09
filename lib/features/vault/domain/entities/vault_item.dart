import 'package:equatable/equatable.dart';

enum VaultItemType { password, bankAccount, atmCard, note }

extension VaultItemTypeX on VaultItemType {
  String get dbValue => switch (this) {
        VaultItemType.password => 'password',
        VaultItemType.bankAccount => 'bank_account',
        VaultItemType.atmCard => 'atm_card',
        VaultItemType.note => 'note',
      };

  String get label => switch (this) {
        VaultItemType.password => 'Password',
        VaultItemType.bankAccount => 'Bank account',
        VaultItemType.atmCard => 'ATM card',
        VaultItemType.note => 'Note',
      };

  String get icon => switch (this) {
        VaultItemType.password => 'lock',
        VaultItemType.bankAccount => 'bank',
        VaultItemType.atmCard => 'card',
        VaultItemType.note => 'note',
      };

  static VaultItemType fromDb(String value) => switch (value) {
        'bank_account' => VaultItemType.bankAccount,
        'atm_card' => VaultItemType.atmCard,
        'note' => VaultItemType.note,
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
  });

  final String id;
  final String userId;
  final VaultItemType type;
  final Map<String, dynamic> fields;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get label => (fields['label'] as String?) ?? 'Untitled';

  VaultItem copyWith({Map<String, dynamic>? fields}) {
    return VaultItem(
      id: id,
      userId: userId,
      type: type,
      fields: fields ?? this.fields,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, type, fields, createdAt, updatedAt];
}

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
