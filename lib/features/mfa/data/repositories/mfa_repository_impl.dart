/// Supabase `mfa_entries` CRUD with DEK-encrypted payloads.
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/core/errors/offline_messages.dart';
import 'package:nucleus/core/network/connectivity_service.dart';
import 'package:nucleus/features/mfa/domain/entities/mfa_entry.dart';
import 'package:nucleus/features/mfa/domain/repositories/mfa_repository.dart';

class MfaRepositoryImpl implements MfaRepository {
  MfaRepositoryImpl(this._client, this._crypto, this._connectivity);

  final SupabaseClient _client;
  final VaultCryptoService _crypto;
  final ConnectivityService _connectivity;
  final _uuid = const Uuid();

  Future<void> _ensureOnline() async {
    if (!await _connectivity.hasConnection()) {
      throw OfflineException(randomOfflineMessage());
    }
  }

  @override
  Future<List<MfaEntry>> listEntries({
    required String userId,
    required Uint8List dek,
  }) async {
    await _ensureOnline();
    final rows = await _client
        .from('mfa_entries')
        .select()
        .eq('user_id', userId)
        .order('sort_order');
    final out = <MfaEntry>[];
    for (final row in rows as List) {
      out.add(await _decrypt(Map<String, dynamic>.from(row as Map), dek));
    }
    return out;
  }

  @override
  Future<MfaEntry?> getEntry({
    required String id,
    required Uint8List dek,
  }) async {
    await _ensureOnline();
    final row =
        await _client.from('mfa_entries').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return _decrypt(Map<String, dynamic>.from(row), dek);
  }

  @override
  Future<MfaEntry> createEntry({
    required String userId,
    required Uint8List dek,
    required String secret,
    required String issuer,
    required String accountName,
    String? vaultItemId,
  }) async {
    await _ensureOnline();
    final id = _uuid.v4();
    final payload = {
      'secret': secret,
      'issuer': issuer,
      'account_name': accountName,
      'algorithm': 'SHA1',
      'digits': 6,
      'period': 30,
    };
    final aad = utf8.encode('mfa:$id');
    final blob = await _crypto.encryptPayload(
      dek: dek,
      plaintextJson: jsonEncode(payload),
      aad: aad,
    );
    final insert = {
      'id': id,
      'user_id': userId,
      'encrypted_payload': blob.ciphertextBase64,
      'nonce': blob.nonceBase64,
      'vault_item_id': vaultItemId,
      'sort_order': 0,
    };
    final row =
        await _client.from('mfa_entries').insert(insert).select().single();
    return _decrypt(Map<String, dynamic>.from(row), dek);
  }

  @override
  Future<MfaEntry> updateEntry({
    required MfaEntry entry,
    required Uint8List dek,
  }) async {
    await _ensureOnline();
    final payload = {
      'secret': entry.secret,
      'issuer': entry.issuer,
      'account_name': entry.accountName,
      'algorithm': entry.algorithm,
      'digits': entry.digits,
      'period': entry.period,
    };
    final aad = utf8.encode('mfa:${entry.id}');
    final blob = await _crypto.encryptPayload(
      dek: dek,
      plaintextJson: jsonEncode(payload),
      aad: aad,
    );
    final row = await _client
        .from('mfa_entries')
        .update({
          'encrypted_payload': blob.ciphertextBase64,
          'nonce': blob.nonceBase64,
          'vault_item_id': entry.vaultItemId,
          'sort_order': entry.sortOrder,
        })
        .eq('id', entry.id)
        .select()
        .single();
    return _decrypt(Map<String, dynamic>.from(row), dek);
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _ensureOnline();
    await _client.from('mfa_entries').delete().eq('id', id);
  }

  Future<MfaEntry> _decrypt(Map<String, dynamic> row, Uint8List dek) async {
    try {
      final id = row['id'] as String;
      final aad = utf8.encode('mfa:$id');
      final json = await _crypto.decryptPayload(
        dek: dek,
        blob: EncryptedBlob(
          ciphertextBase64: row['encrypted_payload'] as String,
          nonceBase64: row['nonce'] as String,
        ),
        aad: aad,
      );
      final fields = Map<String, dynamic>.from(jsonDecode(json) as Map);
      return MfaEntry(
        id: id,
        userId: row['user_id'] as String,
        secret: fields['secret'] as String,
        issuer: fields['issuer'] as String? ?? '',
        accountName: fields['account_name'] as String? ?? '',
        algorithm: fields['algorithm'] as String? ?? 'SHA1',
        digits: fields['digits'] as int? ?? 6,
        period: fields['period'] as int? ?? 30,
        vaultItemId: row['vault_item_id'] as String?,
        sortOrder: row['sort_order'] as int? ?? 0,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      );
    } catch (e) {
      throw VaultException('Failed to decrypt MFA entry', cause: e);
    }
  }
}
