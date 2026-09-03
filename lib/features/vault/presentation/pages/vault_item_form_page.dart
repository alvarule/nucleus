/// Create/edit a vault item. Field keys are the JSON stored inside the encrypted payload.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/features/vault/domain/entities/vault_folder.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/domain/password_field_helpers.dart';
import 'package:nucleus/features/vault/presentation/providers/vault_list_provider.dart';
import 'package:nucleus/features/vault/presentation/widgets/folder_sheets.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/sensitive_access.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart';

class VaultItemFormPage extends ConsumerStatefulWidget {
  const VaultItemFormPage({
    super.key,
    required this.type,
    this.existing,
    this.prefill,
  });

  final VaultItemType type;
  final VaultItem? existing;
  final Map<String, dynamic>? prefill;

  @override
  ConsumerState<VaultItemFormPage> createState() => _VaultItemFormPageState();
}

class _VaultItemFormPageState extends ConsumerState<VaultItemFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _focusNodes = <String, FocusNode>{};
  bool _saving = false;
  String? _accountType = 'savings';
  String? _cardType = 'debit';
  String? _folderId;

  @override
  void initState() {
    super.initState();
    final initial = {
      ...?widget.existing?.fields,
      ...?widget.prefill,
    };
    for (final key in _fieldsFor(widget.type)) {
      _controllers[key] =
          TextEditingController(text: '${initial[key] ?? ''}');
      _focusNodes[key] = FocusNode();
    }
    _accountType = initial['account_type'] as String? ?? 'savings';
    _cardType = initial['card_type'] as String? ?? 'debit';
    _folderId = widget.existing?.folderId;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// Schema per [VaultItemType]; extra dropdowns (account/card type) are not in this list.
  List<String> _fieldsFor(VaultItemType type) => switch (type) {
        VaultItemType.password => ['label', 'url', 'username', 'password', 'notes'],
        VaultItemType.bankAccount => [
            'label',
            'bank_name',
            'account_no',
            'ifsc',
            'micr',
            'notes',
          ],
        VaultItemType.atmCard => [
            'label',
            'bank_name',
            'name_on_card',
            'card_no',
            'cvv',
            'expiry_date',
            'atm_pin',
            'upi_pin',
            'notes',
          ],
        VaultItemType.note => ['label', 'notes'],
      };

  Set<String> get _required => switch (widget.type) {
        VaultItemType.password => {'label', 'username', 'password'},
        VaultItemType.bankAccount => {
            'label',
            'bank_name',
            'account_no',
            'ifsc',
          },
        VaultItemType.atmCard => {
            'label',
            'bank_name',
            'name_on_card',
            'card_no',
            'cvv',
            'expiry_date',
          },
        VaultItemType.note => {'label', 'notes'},
      };

  Set<String> get _sensitive => {
        'password',
        'account_no',
        'cvv',
        'atm_pin',
        'upi_pin',
        'card_no',
      };

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final isEdit = widget.existing != null;
    final keys = _controllers.keys.toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          icon: AppIcon('back', color: colors.textPrimary),
        ),
        title: Text(
          isEdit ? 'Edit ${widget.type.label}' : 'New ${widget.type.label}',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: scale.fontXl,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(scale.lg),
            children: [
              _FolderField(
                folderId: _folderId,
                folders: ref.watch(vaultListProvider).folders,
                onTap: () async {
                  final picked = await showFolderPickerSheet(
                    context: context,
                    ref: ref,
                    folders: ref.read(vaultListProvider).folders,
                    selection: FolderPickerSelection.current,
                    currentFolderId: _folderId,
                  );
                  if (picked == null) return;
                  setState(() => _folderId = picked.isEmpty ? null : picked);
                },
              ),
              SizedBox(height: scale.md),
              ...keys.asMap().entries.map((entry) {
                final index = entry.key;
                final fieldKey = entry.value;
                final isNotes = fieldKey == 'notes';
                final isLast = index == keys.length - 1 &&
                    widget.type != VaultItemType.bankAccount &&
                    widget.type != VaultItemType.atmCard;
                final nextKey = index < keys.length - 1 ? keys[index + 1] : null;

                return Padding(
                  padding: EdgeInsets.only(bottom: scale.md),
                  child: VaultTextField(
                    controller: _controllers[fieldKey]!,
                    focusNode: _focusNodes[fieldKey],
                    label:
                        '${titleCaseLabel(fieldKey)}${_required.contains(fieldKey) ? ' *' : ''}',
                    obscureText: _sensitive.contains(fieldKey),
                    enableObscureToggle: _sensitive.contains(fieldKey),
                    // New items have no stored secret yet; only edits re-auth to show.
                    onBeforeReveal: isEdit && _sensitive.contains(fieldKey)
                        ? () => ensureSensitiveAccess(
                              context,
                              ref,
                              biometricReason: 'Reveal sensitive data',
                            )
                        : null,
                    maxLines: isNotes ? 5 : 1,
                    textInputAction: isNotes
                        ? TextInputAction.newline
                        : (isLast ? TextInputAction.done : TextInputAction.next),
                    onFieldSubmitted: isNotes
                        ? null
                        : (_) {
                            if (nextKey != null) {
                              _focusNodes[nextKey]!.requestFocus();
                            } else if (isLast) {
                              _save();
                            } else {
                              FocusScope.of(context).unfocus();
                            }
                          },
                    validator: (v) {
                      if (_required.contains(fieldKey) &&
                          (v == null || v.trim().isEmpty)) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                );
              }),
              if (widget.type == VaultItemType.bankAccount) ...[
                Text(
                  'Account type *',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: scale.fontSm,
                  ),
                ),
                SizedBox(height: scale.sm),
                DropdownButtonFormField<String>(
                  value: _accountType,
                  items: const [
                    DropdownMenuItem(value: 'savings', child: Text('Savings')),
                    DropdownMenuItem(value: 'current', child: Text('Current')),
                    DropdownMenuItem(value: 'salary', child: Text('Salary')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _accountType = v),
                ),
                SizedBox(height: scale.md),
              ],
              if (widget.type == VaultItemType.atmCard) ...[
                Text(
                  'Card type *',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: scale.fontSm,
                  ),
                ),
                SizedBox(height: scale.sm),
                DropdownButtonFormField<String>(
                  value: _cardType,
                  items: const [
                    DropdownMenuItem(value: 'debit', child: Text('Debit')),
                    DropdownMenuItem(value: 'credit', child: Text('Credit')),
                  ],
                  onChanged: (v) => setState(() => _cardType = v),
                ),
                SizedBox(height: scale.md),
              ],
              PrimaryButton(
                label: isEdit ? 'Save changes' : 'Save to vault',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Persists encrypted fields then lands on detail with Home still under it.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(vaultSessionProvider);
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (!session.isUnlocked || session.dek == null || userId == null) return;

    setState(() => _saving = true);
    final fields = <String, dynamic>{
      for (final e in _controllers.entries) e.key: e.value.text.trim(),
    };
    if (widget.type == VaultItemType.bankAccount) {
      fields['account_type'] = _accountType;
    }
    if (widget.type == VaultItemType.atmCard) {
      fields['card_type'] = _cardType;
    }
    if (widget.type == VaultItemType.password) {
      fields.remove(passwordChangedAtKey);
      final merged = applyPasswordChangedAt(
        fields: fields,
        previousFields: widget.existing?.fields,
        isNew: widget.existing == null,
      );
      fields
        ..clear()
        ..addAll(merged);
    }

    try {
      final repo = ref.read(vaultRepositoryProvider);
      final VaultItem saved;
      if (widget.existing != null) {
        saved = await repo.updateItem(
          item: widget.existing!.copyWith(
            fields: fields,
            folderId: _folderId,
            clearFolderId: _folderId == null,
          ),
          dek: session.dek!,
        );
      } else {
        saved = await repo.createItem(
          userId: userId,
          type: widget.type,
          fields: fields,
          dek: session.dek!,
          folderId: _folderId,
        );
      }
      await ref.read(vaultListProvider.notifier).refresh();
      if (!mounted) return;
      // `go` would wipe the stack (back exits the app). Land on home, then
      // push detail so Android/app-bar back returns to the vault list.
      final router = GoRouter.of(context);
      final detailPath = '/vault/${saved.id}';
      router.go('/home');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        router.push(detailPath);
      });
    } catch (e) {
      if (mounted) {
        final message = await userFacingErrorMessage(
          ref.read(connectivityServiceProvider),
          e,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _FolderField extends StatelessWidget {
  const _FolderField({
    required this.folderId,
    required this.folders,
    required this.onTap,
  });

  final String? folderId;
  final List<VaultFolder> folders;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Scale.of(context);
    final iconSize = scale.iconSm;
    String label = 'Uncategorized';
    if (folderId != null) {
      for (final f in folders) {
        if (f.id == folderId) {
          label = f.name;
          break;
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Folder',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: scale.fontSm,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: scale.sm),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(scale.radiusSm),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: SizedBox(
                width: scale.s(48),
                height: scale.s(48),
                child: Center(
                  child: AppIcon(
                    'folder',
                    size: iconSize,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              suffixIcon: IconButton(
                onPressed: onTap,
                icon: AppIcon(
                  'chevron_down',
                  size: iconSize,
                  color: colors.textSecondary,
                ),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: scale.fontLg,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
