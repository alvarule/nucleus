/// Site authenticator entry (TOTP secret encrypted with vault DEK).
import 'package:equatable/equatable.dart';

class MfaEntry extends Equatable {
  const MfaEntry({
    required this.id,
    required this.userId,
    required this.secret,
    required this.issuer,
    required this.accountName,
    this.algorithm = 'SHA1',
    this.digits = 6,
    this.period = 30,
    this.vaultItemId,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String secret;
  final String issuer;
  final String accountName;
  final String algorithm;
  final int digits;
  final int period;
  final String? vaultItemId;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayTitle =>
      issuer.isNotEmpty ? issuer : accountName;

  MfaEntry copyWith({
    String? issuer,
    String? accountName,
    String? secret,
    String? algorithm,
    int? digits,
    int? period,
    String? vaultItemId,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return MfaEntry(
      id: id,
      userId: userId,
      secret: secret ?? this.secret,
      issuer: issuer ?? this.issuer,
      accountName: accountName ?? this.accountName,
      algorithm: algorithm ?? this.algorithm,
      digits: digits ?? this.digits,
      period: period ?? this.period,
      vaultItemId: vaultItemId ?? this.vaultItemId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, secret, issuer, accountName, vaultItemId, sortOrder];
}
