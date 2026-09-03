/// Generate a password and optionally prefill a new or existing vault password item.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/generator/domain/password_generator.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/shared/widgets/app_buttons.dart';
import 'package:nucleus/shared/widgets/form_setting_row.dart';

class GeneratorPage extends ConsumerStatefulWidget {
  const GeneratorPage({super.key, this.fixItem});

  /// When set, generator is in fix flow for an existing password item.
  final VaultItem? fixItem;

  @override
  ConsumerState<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends ConsumerState<GeneratorPage> {
  final _generator = PasswordGenerator();
  double _length = 16;
  bool _lower = true;
  bool _upper = true;
  bool _numbers = true;
  bool _symbols = true;
  String _password = '';

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    setState(() {
      _password = _generator.generate(
        length: _length.round(),
        lower: _lower,
        upper: _upper,
        numbers: _numbers,
        symbols: _symbols,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    final fixItem = widget.fixItem;
    final isFixFlow = fixItem != null;

    return Scaffold(
      appBar: AppBar(title: Text(isFixFlow ? 'Fix password' : 'Generator')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(scale.md, scale.sm, scale.md, scale.lg),
        children: [
          Container(
            padding: EdgeInsets.all(scale.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(scale.radiusMd),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  _password,
                  style: TextStyle(
                    fontSize: scale.fontLg,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    letterSpacing: 0.5,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: scale.md),
                Row(
                  children: [
                    Text(
                      'Length',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: scale.fontSm,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_length.round()}',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: scale.fontMd,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: scale.s(7),
                    ),
                    overlayShape: RoundSliderOverlayShape(
                      overlayRadius: scale.s(14),
                    ),
                  ),
                  child: Slider(
                    value: _length,
                    min: 8,
                    max: 64,
                    divisions: 56,
                    activeColor: colors.primary,
                    onChanged: (v) {
                      setState(() => _length = v);
                      _regenerate();
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: scale.sm),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: scale.md,
              vertical: scale.xs,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(scale.radiusMd),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                FormSettingRow(
                  label: 'Lowercase',
                  value: _lower,
                  onChanged: (v) {
                    setState(() => _lower = v);
                    _regenerate();
                  },
                ),
                Divider(height: 1, color: colors.border),
                FormSettingRow(
                  label: 'Uppercase',
                  value: _upper,
                  onChanged: (v) {
                    setState(() => _upper = v);
                    _regenerate();
                  },
                ),
                Divider(height: 1, color: colors.border),
                FormSettingRow(
                  label: 'Numbers',
                  value: _numbers,
                  onChanged: (v) {
                    setState(() => _numbers = v);
                    _regenerate();
                  },
                ),
                Divider(height: 1, color: colors.border),
                FormSettingRow(
                  label: 'Special characters',
                  value: _symbols,
                  onChanged: (v) {
                    setState(() => _symbols = v);
                    _regenerate();
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: scale.md),
          PrimaryButton(label: 'Regenerate', onPressed: _regenerate),
          SizedBox(height: scale.sm),
          SecondaryButton(
            label: 'Copy',
            icon: 'copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _password));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied')),
                );
              }
            },
          ),
          SizedBox(height: scale.xs),
          Center(
            child: AppTextButton(
              label: isFixFlow ? 'Update vault item' : 'Save as vault item',
              onPressed: () {
                if (isFixFlow) {
                  context.push(
                    '/vault/edit/${fixItem.id}',
                    extra: {
                      'item': fixItem,
                      'prefill': {'password': _password},
                    },
                  );
                  return;
                }
                context.push(
                  '/vault/new?type=password',
                  extra: <String, dynamic>{'password': _password, 'label': ''},
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
