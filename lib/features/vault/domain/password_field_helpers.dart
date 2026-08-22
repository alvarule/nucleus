/// `password_changed_at` handling for encrypted password payloads.
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';

const passwordChangedAtKey = 'password_changed_at';

/// Parses `password_changed_at` from item fields; null if missing or invalid.
DateTime? parsePasswordChangedAt(VaultItem item) {
  final raw = item.fields[passwordChangedAtKey];
  if (raw == null) return null;
  return DateTime.tryParse('$raw')?.toLocal();
}

/// Sets or preserves `password_changed_at` when saving a password item.
Map<String, dynamic> applyPasswordChangedAt({
  required Map<String, dynamic> fields,
  Map<String, dynamic>? previousFields,
  required bool isNew,
}) {
  final next = Map<String, dynamic>.from(fields);
  final password = '${next['password'] ?? ''}'.trim();
  if (password.isEmpty) return next;

  final now = DateTime.now().toUtc().toIso8601String();

  if (isNew) {
    next[passwordChangedAtKey] = now;
    return next;
  }

  final previousPassword = '${previousFields?['password'] ?? ''}'.trim();
  if (password != previousPassword) {
    next[passwordChangedAtKey] = now;
  } else {
    final existing = previousFields?[passwordChangedAtKey];
    if (existing != null) {
      next[passwordChangedAtKey] = existing;
    }
  }

  return next;
}
