import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultify/core/di/providers.dart';
import 'package:vaultify/core/responsive/scale.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:vaultify/features/vault/domain/entities/vault_item.dart';
import 'package:vaultify/features/vault/presentation/providers/vault_list_provider.dart';
import 'package:vaultify/shared/widgets/app_icon.dart';
import 'package:vaultify/shared/widgets/vault_text_field.dart';

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
  bool _saving = false;
  String? _accountType = 'savings';
  String? _cardType = 'debit';

  @override
  void initState() {
    super.initState();
    final initial = {
      ...?widget.prefill,
      ...?widget.existing?.fields,
    };
    for (final key in _fieldsFor(widget.type)) {
      _controllers[key] =
          TextEditingController(text: '${initial[key] ?? ''}');
    }
    _accountType = initial['account_type'] as String? ?? 'savings';
    _cardType = initial['card_type'] as String? ?? 'debit';
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

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

  String _label(String key) => key.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: AppIcon('back', color: colors.textPrimary),
        ),
        title: Text(isEdit ? 'Edit ${widget.type.label}' : 'New ${widget.type.label}'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(scale.lg),
            children: [
              ..._controllers.entries.map((e) {
                final isNotes = e.key == 'notes';
                return Padding(
                  padding: EdgeInsets.only(bottom: scale.md),
                  child: VaultTextField(
                    controller: e.value,
                    label: '${_label(e.key)}${_required.contains(e.key) ? ' *' : ''}',
                    obscureText: _sensitive.contains(e.key),
                    maxLines: isNotes ? 5 : 1,
                    validator: (v) {
                      if (_required.contains(e.key) &&
                          (v == null || v.trim().isEmpty)) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                );
              }),
              if (widget.type == VaultItemType.bankAccount) ...[
                Text('Account type *',
                    style: TextStyle(color: colors.textSecondary, fontSize: scale.fontSm)),
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
                Text('Card type *',
                    style: TextStyle(color: colors.textSecondary, fontSize: scale.fontSm)),
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

    try {
      final repo = ref.read(vaultRepositoryProvider);
      if (widget.existing != null) {
        await repo.updateItem(
          item: widget.existing!.copyWith(fields: fields),
          dek: session.dek!,
        );
      } else {
        await repo.createItem(
          userId: userId,
          type: widget.type,
          fields: fields,
          dek: session.dek!,
        );
      }
      await ref.read(vaultListProvider.notifier).refresh();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
