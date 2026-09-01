/// App entry: load `.env`, initialize Supabase, enable screenshot protection,
/// then boot [NucleusApp] inside a Riverpod [ProviderScope].
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nucleus/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final url = dotenv.env['SUPABASE_URL'] ?? '';
  // Prefer the current publishable key; fall back to the older anon-key name.
  final publishableKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
      dotenv.env['SUPABASE_ANON_KEY'] ??
      '';
  if (url.isNotEmpty &&
      publishableKey.isNotEmpty &&
      !url.contains('YOUR_PROJECT') &&
      publishableKey != 'your_publishable_key_here' &&
      publishableKey != 'your_anon_key_here') {
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUri: true,
      ),
    );
  } else {
    // Placeholder so widgets can mount in tests/dev without real credentials.
    // Auth and vault calls will fail until `.env` is configured.
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBsYWNlaG9sZGVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE2NDUxOTI4MDAsImV4cCI6MTk2MDc2ODgwMH0.placeholder',
    );
  }

  try {
    await ScreenProtector.protectDataLeakageOn();
  } catch (_) {
    // Platform may not support during tests.
  }

  runApp(const ProviderScope(child: NucleusApp()));
}
