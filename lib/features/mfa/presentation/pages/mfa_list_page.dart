/// Site authenticator list (MFA tab) with issuer/account search.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/mfa/domain/entities/mfa_entry.dart';
import 'package:nucleus/features/mfa/presentation/providers/mfa_list_provider.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/vault_loader.dart';

class MfaListPage extends ConsumerStatefulWidget {
  const MfaListPage({super.key});

  @override
  ConsumerState<MfaListPage> createState() => _MfaListPageState();
}

class _MfaListPageState extends ConsumerState<MfaListPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<MfaEntry> _filterEntries(List<MfaEntry> entries) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries.where((e) => _entryMatchesQuery(e, q)).toList();
  }

  /// Matches issuer, account (username/email), and display title.
  static bool _entryMatchesQuery(MfaEntry entry, String q) {
    return entry.issuer.toLowerCase().contains(q) ||
        entry.accountName.toLowerCase().contains(q) ||
        entry.displayTitle.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final list = ref.watch(mfaListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MFA'),
        actions: [
          IconButton(
            onPressed: () => context.push('/mfa/scan'),
            icon: AppIcon('plus', color: colors.primary),
          ),
          IconButton(
            onPressed: () => context.push('/mfa/new'),
            icon: AppIcon('edit', color: colors.primary),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              scale.md,
              0,
              scale.md,
              scale.sm,
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              onTapOutside: (_) => _searchFocus.unfocus(),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: scale.fontMd,
              ),
              decoration: InputDecoration(
                hintText: 'Search authenticators',
                hintStyle: TextStyle(
                  color: colors.textTertiary,
                  fontSize: scale.fontMd,
                ),
                prefixIcon: Padding(
                  padding: EdgeInsets.all(scale.sm + 2),
                  child: AppIcon('search', color: colors.textSecondary),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _searchFocus.unfocus();
                        },
                        icon: AppIcon(
                          'close',
                          color: colors.textSecondary,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: colors.surfaceMuted,
              ),
            ),
          ),
          Expanded(
            child: list.when(
              loading: () => const Center(child: VaultLoader()),
              error: (e, _) => Center(child: Text('$e')),
              data: (entries) {
                final visible = _filterEntries(entries);
                if (entries.isEmpty) {
                  return _MfaEmptyState(
                    title: 'No authenticators yet',
                    message: 'Scan a QR code or add an entry manually',
                  );
                }
                if (visible.isEmpty) {
                  return _MfaEmptyState(
                    title: 'No matches',
                    message: 'Try a different issuer or account name',
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.only(bottom: scale.lg),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final entry = visible[index];
                    return Column(
                      children: [
                        _MfaEntryTile(
                          entry: entry,
                          onTap: () => context.push('/mfa/${entry.id}'),
                        ),
                        Divider(height: 1, color: colors.border),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MfaEmptyState extends StatelessWidget {
  const _MfaEmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(scale.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: scale.s(56),
              height: scale.s(56),
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(scale.radiusMd),
              ),
              child: Center(
                child: AppIcon('shield', color: colors.primary),
              ),
            ),
            SizedBox(height: scale.md),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: scale.fontLg,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: scale.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: scale.fontMd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MfaEntryTile extends StatelessWidget {
  const _MfaEntryTile({
    required this.entry,
    required this.onTap,
  });

  final MfaEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final subtitle = entry.accountName.isNotEmpty
        ? entry.accountName
        : (entry.issuer.isNotEmpty ? null : 'Authenticator');

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(
        horizontal: scale.md,
        vertical: scale.xs,
      ),
      leading: Container(
        width: scale.s(44),
        height: scale.s(44),
        decoration: BoxDecoration(
          color: colors.primarySoft,
          borderRadius: BorderRadius.circular(scale.radiusSm),
        ),
        child: Center(
          child: AppIcon('shield', color: colors.primary),
        ),
      ),
      title: Text(
        entry.displayTitle,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: scale.fontLg,
          color: colors.textPrimary,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: scale.fontSm,
              ),
            ),
      trailing: AppIcon('chevron_right', color: colors.textTertiary),
    );
  }
}
