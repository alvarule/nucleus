/// Home tab: folder-grouped vault list, type chips, global search, sort.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/health/domain/entities/item_health_snapshot.dart';
import 'package:nucleus/features/health/presentation/providers/password_health_provider.dart';
import 'package:nucleus/features/health/presentation/widgets/health_badge.dart';
import 'package:nucleus/features/profile/presentation/widgets/avatar_widget.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/domain/folder_sections.dart';
import 'package:nucleus/features/vault/presentation/providers/vault_list_provider.dart';
import 'package:nucleus/features/vault/presentation/widgets/folder_sheets.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/sensitive_access.dart';
import 'package:nucleus/shared/widgets/vault_home_skeleton.dart';

class VaultHomePage extends ConsumerStatefulWidget {
  const VaultHomePage({super.key});

  @override
  ConsumerState<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends ConsumerState<VaultHomePage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  final _collapsed = <String>{};
  final _headerKeys = <String, GlobalKey>{};
  final _selectedIds = <String>{};

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
    _scrollController.dispose();
    super.dispose();
  }

  bool get _selectionMode => _selectedIds.isNotEmpty;

  GlobalKey _headerKeyFor(String folderId) =>
      _headerKeys.putIfAbsent(folderId, GlobalKey.new);

  Widget _folderHeaderForSection(
    VaultFolderSection section,
    List<VaultFolderSection> sections,
  ) {
    return _FolderHeader(
      title: section.title,
      count: section.items.length,
      expanded: !_collapsed.contains(section.folderId),
      onTapName: () => _jumpToFolder(sections),
      onToggle: () {
        setState(() {
          if (_collapsed.contains(section.folderId)) {
            _collapsed.remove(section.folderId);
          } else {
            _collapsed.add(section.folderId);
          }
        });
      },
      onLongPress: () => showFolderManageSheet(
        context: context,
        ref: ref,
        folderId: section.folderId,
        title: section.title,
      ),
    );
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  void _toggleItemSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _moveSelectedItems() async {
    final state = ref.read(vaultListProvider);
    if (_selectedIds.isEmpty) return;

    final picked = await showFolderPickerSheet(
      context: context,
      ref: ref,
      folders: state.folders,
    );
    if (picked == null || !mounted) return;

    final folderId = picked.isEmpty ? null : picked;
    try {
      await ref.read(vaultListProvider.notifier).moveItemsToFolder(
            _selectedIds,
            folderId,
          );
      if (!mounted) return;
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Items moved')),
      );
    } catch (e) {
      final message = await userFacingErrorMessage(
        ref.read(connectivityServiceProvider),
        e,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  /// Copy is a sensitive action — same gate as reveal.
  Future<void> _copyPassword(VaultItem item) async {
    final password = '${item.fields['password'] ?? ''}';
    if (password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No password on this item')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password copied')));
  }

  Future<bool> _confirmDelete(VaultItem item) async {
    final colors = context.colors;
    final scale = Scale.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete item?',
          style: TextStyle(fontSize: scale.fontXl, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Delete "${item.label}"? This cannot be undone.',
          style: TextStyle(color: colors.textSecondary, fontSize: scale.fontMd),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(fontSize: scale.fontMd)),
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

  Future<void> _jumpToFolder(List<VaultFolderSection> sections) async {
    final colors = context.colors;
    final scale = Scale.of(context);
    final target = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(scale.radiusLg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(scale.md, 0, scale.md, scale.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Jump to folder',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: scale.fontLg,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: scale.md),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: sections.map((s) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: scale.xs),
                        child: Material(
                          color: colors.surfaceMuted,
                          borderRadius:
                              BorderRadius.circular(scale.radiusSm),
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx, s.folderId),
                            borderRadius:
                                BorderRadius.circular(scale.radiusSm),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: scale.md,
                                vertical: scale.sm + 2,
                              ),
                              child: Row(
                                children: [
                                  AppIcon(
                                    'folder',
                                    size: scale.iconSm,
                                    color: s.isUncategorized
                                        ? colors.textSecondary
                                        : colors.primary,
                                  ),
                                  SizedBox(width: scale.md),
                                  Expanded(
                                    child: Text(
                                      s.title,
                                      style: TextStyle(
                                        fontSize: scale.fontMd,
                                        fontWeight: FontWeight.w500,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${s.items.length}',
                                    style: TextStyle(
                                      fontSize: scale.fontSm,
                                      color: colors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (target == null || !mounted) return;

    if (_collapsed.contains(target)) {
      setState(() => _collapsed.remove(target));
    }

    void scrollToHeader() {
      final headerContext = _headerKeyFor(target).currentContext;
      if (headerContext != null && headerContext.mounted) {
        Scrollable.ensureVisible(
          headerContext,
          duration: const Duration(milliseconds: 280),
          alignment: 0,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => scrollToHeader());
  }

  void _showSortSheet() {
    showSortSheet(
      context: context,
      ref: ref,
      current: ref.read(vaultListProvider).sort,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final state = ref.watch(vaultListProvider);
    final health = ref.watch(passwordHealthProvider);
    final profile = ref.watch(vaultSessionProvider).profile;
    final firstName = _firstName(profile?.name);
    final showSkeleton = !state.hasLoaded;
    final sections = state.sections;

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode) _clearSelection();
      },
      child: GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.deferToChild,
      child: Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          titleSpacing: scale.md,
          title: Row(
            children: [
              GestureDetector(
                onTap: showSkeleton
                    ? null
                    : () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        context.push('/profile');
                      },
                child: profile != null
                    ? Hero(
                        tag: 'profile_avatar',
                        child: AvatarWidget(
                          profile: profile,
                          size: scale.s(36),
                        ),
                      )
                    : Hero(
                        tag: 'profile_avatar',
                        child: _PlaceholderAvatar(size: scale.s(36)),
                      ),
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
              if (!showSkeleton)
                IconButton(
                  tooltip: 'Sort',
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _showSortSheet();
                  },
                  icon: AppIcon('sort', color: colors.textSecondary),
                ),
            ],
          ),
        ),
        floatingActionButton: showSkeleton || _selectionMode
            ? null
            : FloatingActionButton(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _showAddSheet(context);
                },
                child: AppIcon('plus', color: colors.onPrimary),
              ),
        bottomNavigationBar: _selectionMode
            ? Material(
                elevation: 8,
                color: colors.surface,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: scale.md,
                      vertical: scale.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_selectedIds.length} selected',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: scale.fontMd,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _clearSelection,
                          child: Text(
                            'Cancel',
                            style: TextStyle(fontSize: scale.fontMd),
                          ),
                        ),
                        SizedBox(width: scale.sm),
                        FilledButton.icon(
                          onPressed: _moveSelectedItems,
                          icon: AppIcon(
                            'folder',
                            size: scale.iconSm,
                            color: colors.onPrimary,
                          ),
                          label: const Text('Move'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
        body: showSkeleton
            ? const VaultHomeSkeleton()
            : Column(
                children: [
                  if (state.error != null)
                    MaterialBanner(
                      content: Text(state.error!),
                      actions: [
                        TextButton(
                          onPressed: () => ref
                              .read(vaultListProvider.notifier)
                              .refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
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
                                  ref
                                      .read(vaultListProvider.notifier)
                                      .setQuery('');
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
                            ref
                                .read(vaultListProvider.notifier)
                                .setFilter(null);
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
                  SizedBox(height: scale.s(6)),
                  Expanded(
                    child: NotificationListener<UserScrollNotification>(
                      onNotification: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        return false;
                      },
                      child:
                          state.visible.isEmpty &&
                              sections.every((s) => s.items.isEmpty) &&
                              state.query.trim().isNotEmpty
                          ? Center(
                              child: Text(
                                'No matching items.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: scale.fontMd,
                                  height: 1.4,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => ref
                                  .read(vaultListProvider.notifier)
                                  .refresh(),
                              child: CustomScrollView(
                                controller: _scrollController,
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  for (final section in sections)
                                    SliverStickyHeader(
                                      header: ColoredBox(
                                        color: colors.bg,
                                        child: KeyedSubtree(
                                          key: _headerKeyFor(
                                            section.folderId,
                                          ),
                                          child: _folderHeaderForSection(
                                            section,
                                            sections,
                                          ),
                                        ),
                                      ),
                                      sliver: _collapsed.contains(
                                        section.folderId,
                                      )
                                          ? const SliverToBoxAdapter(
                                              child: SizedBox.shrink(),
                                            )
                                          : SliverList(
                                              delegate:
                                                  SliverChildBuilderDelegate(
                                                (context, itemIndex) {
                                                  final item = section
                                                      .items[itemIndex];
                                                  final selected = _selectedIds
                                                      .contains(item.id);
                                                  return _VaultItemTile(
                                                    item: item,
                                                    health: item.type ==
                                                            VaultItemType
                                                                .password
                                                        ? health
                                                            .forItem(item.id)
                                                        : null,
                                                    selectionMode:
                                                        _selectionMode,
                                                    selected: selected,
                                                    onCopy: () =>
                                                        _copyPassword(item),
                                                    onOpen: () {
                                                      if (_selectionMode) {
                                                        _toggleItemSelection(
                                                          item.id,
                                                        );
                                                        return;
                                                      }
                                                      FocusManager
                                                          .instance
                                                          .primaryFocus
                                                          ?.unfocus();
                                                      context.push(
                                                        '/vault/${item.id}',
                                                      );
                                                    },
                                                    onLongPress: () {
                                                      HapticFeedback
                                                          .mediumImpact();
                                                      setState(
                                                        () => _selectedIds
                                                            .add(item.id),
                                                      );
                                                    },
                                                    confirmDelete: () =>
                                                        _confirmDelete(item),
                                                    onDeleted: () {
                                                      ref
                                                          .read(
                                                            vaultListProvider
                                                                .notifier,
                                                          )
                                                          .delete(item.id);
                                                    },
                                                  );
                                                },
                                                childCount:
                                                    section.items.length,
                                              ),
                                            ),
                                    ),
                                  SliverPadding(
                                    padding: EdgeInsets.only(
                                      bottom: scale.s(80),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
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

class _FolderHeader extends StatelessWidget {
  const _FolderHeader({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onTapName,
    required this.onToggle,
    required this.onLongPress,
  });

  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onTapName;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Scale.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(scale.md, scale.xs, scale.md, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(scale.radiusSm),
        ),
        child: Material(
          type: MaterialType.transparency,
          surfaceTintColor: Colors.transparent,
          child: InkWell(
            onTap: onTapName,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(scale.radiusSm),
            child: Padding(
              padding: EdgeInsets.only(
                left: scale.sm,
                right: scale.xs,
                top: scale.xs,
                bottom: scale.xs,
              ),
              child: Row(
                children: [
                  AppIcon('folder', color: colors.primary, size: scale.iconSm),
                  SizedBox(width: scale.sm),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: scale.fontSm,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: scale.sm,
                      vertical: scale.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(scale.radiusSm),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: scale.fontSm,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: expanded ? 'Collapse' : 'Expand',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: scale.s(36),
                      minHeight: scale.s(36),
                    ),
                    onPressed: onToggle,
                    icon: AnimatedRotation(
                      turns: expanded ? 0 : -0.25,
                      duration: const Duration(milliseconds: 180),
                      child: AppIcon(
                        'chevron_down',
                        color: colors.textSecondary,
                        size: scale.iconSm,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VaultItemTile extends StatelessWidget {
  const _VaultItemTile({
    required this.item,
    required this.health,
    required this.selectionMode,
    required this.selected,
    required this.onCopy,
    required this.onOpen,
    required this.onLongPress,
    required this.confirmDelete,
    required this.onDeleted,
  });

  final VaultItem item;
  final ItemHealthSnapshot? health;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onCopy;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final hasPassword = '${item.fields['password'] ?? ''}'.isNotEmpty;
    final subtitle = item.listSubtitle;
    final showBadge =
        health != null && health!.primaryFlag != ItemHealthFlag.fine;

    final tile = Column(
      children: [
        ListTile(
          onLongPress: onLongPress,
          leading: selectionMode
              ? Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? colors.primary : colors.textTertiary,
                  size: scale.iconMd,
                )
              : Container(
                  width: scale.s(44),
                  height: scale.s(44),
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(scale.radiusSm),
                  ),
                  child: Center(
                    child: AppIcon(item.type.icon, color: colors.primary),
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
          trailing: selectionMode
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showBadge)
                      Padding(
                        padding: EdgeInsets.only(right: scale.xs),
                        child: HealthBadge(snapshot: health!),
                      ),
                    if (hasPassword)
                      IconButton(
                        tooltip: 'Copy password',
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          onCopy();
                        },
                        icon: AppIcon('copy', color: colors.textSecondary),
                      ),
                    AppIcon('chevron_right', color: colors.textTertiary),
                  ],
                ),
          selected: selected,
          selectedTileColor: colors.primarySoft.withValues(alpha: 0.35),
          onTap: onOpen,
        ),
        Divider(height: 1, color: colors.border),
      ],
    );

    if (selectionMode) return tile;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDelete(),
      onDismissed: (_) => onDeleted(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: scale.lg),
        color: colors.danger,
        child: AppIcon('delete', color: colors.onPrimary),
      ),
      child: tile,
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
