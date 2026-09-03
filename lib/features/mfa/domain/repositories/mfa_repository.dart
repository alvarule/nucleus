/// Cloud-synced site TOTP entries and login TOTP secret (KEK-wrapped).
import 'dart:typed_data';

import 'package:nucleus/features/mfa/domain/entities/mfa_entry.dart';

abstract class MfaRepository {
  Future<List<MfaEntry>> listEntries({
    required String userId,
    required Uint8List dek,
  });

  Future<MfaEntry> createEntry({
    required String userId,
    required Uint8List dek,
    required String secret,
    required String issuer,
    required String accountName,
    String? vaultItemId,
  });

  Future<MfaEntry> updateEntry({
    required MfaEntry entry,
    required Uint8List dek,
  });

  Future<void> deleteEntry(String id);

  Future<MfaEntry?> getEntry({
    required String id,
    required Uint8List dek,
  });
}
