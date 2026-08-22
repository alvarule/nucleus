/// Home tab: searchable vault list, type chips, swipe-delete, copy-password.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/profile/presentation/widgets/avatar_widget.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/features/health/presentation/providers/password_health_provider.dart';
import 'package:nucleus/features/health/presentation/widgets/health_badge.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/presentation/providers/vault_list_provider.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/sensitive_access.dart';
import 'package:nucleus/shared/widgets/vault_loader.dart';

class VaultHomePage extends ConsumerStatefulWidget {
  const VaultHomePage({super.key});

  @override
  ConsumerState<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends ConsumerState<VaultHomePage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    Future.microtask(() => ref.read(vaultListProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Copy is a sensitive action — same gate as reveal.
  Future<void> _copyPassword(VaultItem item) async {
    final password = '${item.fields['password'] ?? ''}';
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No password on this item')),
      );
      return;
    }
    final ok = await ensureSensitiveAccess(
      context,
      ref,
      biometricReason: 'Confirm to copy password',
    );
    if (!ok || !mounted) return;
    await Clipboard.setData(ClipboardData(text: password));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password copied')),
    );
  }

  Future<bool> _confirmDelete(VaultItem item) async {
    final colors = context.colors;
    final scale = Scale.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete item?',
          style: TextStyle(
            fontSize: scale.fontXl,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Delete "${item.label}"? This cannot be undone.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: scale.fontMd,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: scale.fontMd),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: colors.danger,
                fontSize: scale.fontMd,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final state = ref.watch(vaultListProvider);
    final health = ref.watch(passwordHealthProvider);
    final profile = ref.watch(vaultSessionProvider).profile;
    final firstName = _firstName(profile?.name);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.deferToChild,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: scale.md,
          title: Row(
            children: [
              // if (profile != null)
              //   AvatarWidget(profile: profile, size: scale.s(36))
              // else
              //   _PlaceholderAvatar(size: scale.s(36)),
              GestureDetector(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  context.push('/profile');
                },
                child: profile != null ? 
                Hero(tag: 'profile_avatar', child:AvatarWidget(profile: profile, size: scale.s(36))) : 
                Hero(tag: 'profile_avatar', child: _PlaceholderAvatar(size: scale.s(36))),
              ),
              SizedBox(width: scale.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: scale.fontSm,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: scale.xs),
                    Text(
                      firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: scale.fontLg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // actions: [
          //   IconButton(
          //     onPressed: () {
          //       FocusManager.instance.primaryFocus?.unfocus();
          //       context.push('/profile');
          //     },
          //     icon: AppIcon('user', color: colors.primary),
          //   ),
          // ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            _showAddSheet(context);
          },
          child: AppIcon('plus', color: colors.onPrimary),
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(scale.md, 0, scale.md, scale.sm),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: ref.read(vaultListProvider.notifier).setQuery,
                textInputAction: TextInputAction.search,
                onTapOutside: (_) => _searchFocus.unfocus(),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: scale.fontMd,
                ),
                decoration: InputDecoration(
                  hintText: 'Search vault',
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
                            ref.read(vaultListProvider.notifier).setQuery('');
                            _searchFocus.unfocus();
                          },
                          icon: AppIcon('close', color: colors.textSecondary),
                        )
                      : null,
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
                    icon: 'home',
                    selected: state.filter == null,
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      ref.read(vaultListProvider.notifier).setFilter(null);
                    },
                  ),
                  ...VaultItemType.values.map(
                    (t) => _FilterChip(
                      label: t.label,
                      icon: t.icon,
                      selected: state.filter == t,
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        ref.read(vaultListProvider.notifier).setFilter(t);
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: scale.sm),
            Expanded(
              child: NotificationListener<UserScrollNotification>(
                onNotification: (_) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  return false;
                },
                child: state.loading
                    ? const VaultLoader()
                    : state.visible.isEmpty
                        ? Center(
                            child: Text(
                              'No items yet.\nTap + to add your first secret.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: scale.fontMd,
                                height: 1.4,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () =>
                                ref.read(vaultListProvider.notifier).refresh(),
                            child: ListView.separated(
                              itemCount: state.visible.length,
                              padding: EdgeInsets.only(
                                bottom: scale.s(80),
                              ),
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, color: colors.border),
                              itemBuilder: (context, index) {
                                final item = state.visible[index];
                                final hasPassword =
                                    '${item.fields['password'] ?? ''}'.isNotEmpty;
                                final subtitle = item.listSubtitle;
                                final healthSnapshot = item.type ==
                                        VaultItemType.password
                                    ? health.forItem(item.id)
                                    : null;
                                return Dismissible(
                                  key: ValueKey(item.id),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) => _confirmDelete(item),
                                  onDismissed: (_) {
                                    ref
                                        .read(vaultListProvider.notifier)
                                        .delete(item.id);
                                  },
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: scale.lg,
                                    ),
                                    color: colors.danger,
                                    child: AppIcon(
                                      'delete',
                                      color: colors.onPrimary,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      width: scale.s(44),
                                      height: scale.s(44),
                                      decoration: BoxDecoration(
                                        color: colors.primarySoft,
                                        borderRadius: BorderRadius.circular(
                                          scale.radiusSm,
                                        ),
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
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (healthSnapshot != null)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              right: scale.xs,
                                            ),
                                            child: HealthBadge(
                                              snapshot: healthSnapshot,
                                            ),
                                          ),
                                        if (hasPassword)
                                          IconButton(
                                            tooltip: 'Copy password',
                                            onPressed: () {
                                              FocusManager
                                                  .instance.primaryFocus
                                                  ?.unfocus();
                                              _copyPassword(item);
                                            },
                                            icon: AppIcon(
                                              'copy',
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        AppIcon(
                                          'chevron_right',
                                          color: colors.textTertiary,
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      context.push('/vault/${item.id}');
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _firstName(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
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
              const ListTile(
                title: Text(
                  'Add vault item',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ...VaultItemType.values.map(
                (t) => ListTile(
                  leading: AppIcon(t.icon, color: colors.primary),
                  title: Text(
                    t.label,
                    style: TextStyle(fontSize: Scale.of(ctx).fontLg),
                  ),
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

class _PlaceholderAvatar extends StatelessWidget {
  const _PlaceholderAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primarySoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AppIcon('user', size: size * 0.45, color: colors.primary),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Scale.of(context);
    final iconColor = selected ? colors.primary : colors.textSecondary;
    return Padding(
      padding: EdgeInsets.only(right: scale.sm),
      child: ChoiceChip(
        avatar: AppIcon(icon, size: scale.iconSm, color: iconColor),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: colors.primarySoft,
        labelStyle: TextStyle(
          color: selected ? colors.primary : colors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: scale.fontSm,
        ),
        side: BorderSide(color: selected ? colors.primary : colors.border),
        backgroundColor: colors.surface,
      ),
    );
  }
}
