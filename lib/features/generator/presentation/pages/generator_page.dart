/// Generate a password and optionally prefill a new vault password item.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/generator/domain/password_generator.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart';

class GeneratorPage extends ConsumerStatefulWidget {
  const GeneratorPage({super.key});

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

    return Scaffold(
      appBar: AppBar(title: const Text('Generator')),
      body: ListView(
        padding: EdgeInsets.all(scale.lg),
        children: [
          Container(
            padding: EdgeInsets.all(scale.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(scale.radiusLg),
              border: Border.all(color: colors.border),
            ),
            child: SelectableText(
              _password,
              style: TextStyle(
                fontSize: scale.fontXl,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                letterSpacing: 1,
              ),
            ),
          ),
          SizedBox(height: scale.lg),
          Text(
            'Length: ${_length.round()}',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: scale.fontMd,
            ),
          ),
          Slider(
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
          SwitchListTile(
            title: const Text('Lowercase'),
            value: _lower,
            activeThumbColor: colors.primary,
            onChanged: (v) {
              setState(() => _lower = v);
              _regenerate();
            },
          ),
          SwitchListTile(
            title: const Text('Uppercase'),
            value: _upper,
            activeThumbColor: colors.primary,
            onChanged: (v) {
              setState(() => _upper = v);
              _regenerate();
            },
          ),
          SwitchListTile(
            title: const Text('Numbers'),
            value: _numbers,
            activeThumbColor: colors.primary,
            onChanged: (v) {
              setState(() => _numbers = v);
              _regenerate();
            },
          ),
          SwitchListTile(
            title: const Text('Special characters'),
            value: _symbols,
            activeThumbColor: colors.primary,
            onChanged: (v) {
              setState(() => _symbols = v);
              _regenerate();
            },
          ),
          SizedBox(height: scale.md),
          PrimaryButton(label: 'Regenerate', onPressed: _regenerate),
          SizedBox(height: scale.sm),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _password));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied')),
                );
              }
            },
            icon: AppIcon('copy', color: colors.primary),
            label: Text('Copy', style: TextStyle(color: colors.primary)),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(scale.s(52)),
              side: BorderSide(color: colors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(scale.radiusMd),
              ),
            ),
          ),
          SizedBox(height: scale.sm),
          TextButton(
            onPressed: () {
              // `extra` prefills the form; router must not refresh or it is dropped.
              context.push(
                '/vault/new?type=password',
                extra: <String, dynamic>{'password': _password, 'label': ''},
              );
            },
            child: Text(
              'Save as vault item',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
