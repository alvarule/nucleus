/// Display titles and identifiers for Health list rows.
import 'package:intl/intl.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';

/// Builds `{label} — {identifier}` with collision disambiguation.
String healthDisplayTitle(
  VaultItem item, {
  required List<VaultItem> allPasswordItems,
}) {
  final label = item.label;
  final identifier = _identifier(item);
  var title = '$label — $identifier';

  final collisions = allPasswordItems.where((other) {
    if (other.id == item.id) return false;
    return other.label == label && _identifier(other) == identifier;
  }).toList();

  if (collisions.isNotEmpty) {
    final date = DateFormat.yMMMd().format(item.updatedAt);
    title = '$title ($date)';
  }

  return title;
}

String _identifier(VaultItem item) {
  final username = '${item.fields['username'] ?? ''}'.trim();
  if (username.isNotEmpty) return username;

  final url = '${item.fields['url'] ?? ''}'.trim();
  if (url.isEmpty) return 'No username';

  final host = Uri.tryParse(url.contains('://') ? url : 'https://$url')?.host;
  if (host != null && host.isNotEmpty) return host;

  return url;
}
