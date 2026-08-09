import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultify/core/responsive/scale.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/features/vault/domain/entities/vault_item.dart';
import 'package:vaultify/features/vault/presentation/providers/vault_list_provider.dart';
import 'package:vaultify/shared/widgets/app_icon.dart';
import 'package:vaultify/shared/widgets/vault_loader.dart';

class VaultHomePage extends ConsumerStatefulWidget {
  const VaultHomePage({super.key});

  @override
  ConsumerState<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends ConsumerState<VaultHomePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(vaultListProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final state = ref.watch(vaultListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: AppIcon('user', color: colors.primary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        child: AppIcon('plus', color: colors.onPrimary),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(scale.md, 0, scale.md, scale.sm),
            child: TextField(
              onChanged: ref.read(vaultListProvider.notifier).setQuery,
              decoration: InputDecoration(
                hintText: 'Search vault',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(scale.sm + 2),
                  child: AppIcon('search', color: colors.textSecondary),
                ),
                filled: true,
                fillColor: colors.surfaceMuted,
              ),
            ),
          ),
          SizedBox(
            height: scale.s(40),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: scale.md),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: state.filter == null,
                  onTap: () => ref.read(vaultListProvider.notifier).setFilter(null),
                ),
                ...VaultItemType.values.map(
                  (t) => _FilterChip(
                    label: t.label,
                    selected: state.filter == t,
                    onTap: () => ref.read(vaultListProvider.notifier).setFilter(t),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: scale.sm),
          Expanded(
            child: state.loading
                ? const VaultLoader()
                : state.visible.isEmpty
                    ? Center(
                        child: Text(
                          'No items yet.\nTap + to add your first secret.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(vaultListProvider.notifier).refresh(),
                        child: ListView.separated(
                          itemCount: state.visible.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: colors.border),
                          itemBuilder: (context, index) {
                            final item = state.visible[index];
                            return ListTile(
                              leading: Container(
                                width: scale.s(44),
                                height: scale.s(44),
                                decoration: BoxDecoration(
                                  color: colors.primarySoft,
                                  borderRadius:
                                      BorderRadius.circular(scale.radiusSm),
                                ),
                                child: Center(
                                  child: AppIcon(
                                    item.type.icon,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                              title: Text(
                                item.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                item.type.label,
                                style: TextStyle(color: colors.textSecondary),
                              ),
                              trailing: AppIcon(
                                'chevron_right',
                                color: colors.textTertiary,
                              ),
                              onTap: () => context.push('/vault/${item.id}'),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final colors = context.colors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Add vault item')),
              ...VaultItemType.values.map(
                (t) => ListTile(
                  leading: AppIcon(t.icon, color: colors.primary),
                  title: Text(t.label),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/vault/new?type=${t.dbValue}');
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Scale.of(context);
    return Padding(
      padding: EdgeInsets.only(right: scale.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: colors.primarySoft,
        labelStyle: TextStyle(
          color: selected ? colors.primary : colors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(color: selected ? colors.primary : colors.border),
        backgroundColor: colors.surface,
      ),
    );
  }
}
