# Changelog

## [2026-08-23] Password health — triage view, vault badges, reuse fix

**Summary:** Rebuilt password health per plan: shared session health scoring (`EvaluatePasswordHealth`), vault home badges, Health tab filters (All/Weak/Reused/Old), reused-password grouping, weak/reused listed above strong, Fix now flow via `/generator/fix` → edit, `password_changed_at` payload field, Settings password-age threshold (90/180 days). Fixed reuse detection to count duplicate passwords instead of marking all items when the vault has 2+ unique passwords.
**Files:** `lib/features/health/domain/**`, `lib/features/health/presentation/**`, `lib/features/vault/domain/password_field_helpers.dart`, `lib/features/vault/presentation/pages/vault_home_page.dart`, `lib/features/vault/presentation/pages/vault_item_detail_page.dart`, `lib/features/vault/presentation/pages/vault_item_form_page.dart`, `lib/features/generator/**`, `lib/features/settings/**`, `lib/router/app_router.dart`, `test/widget_test.dart`, `docs/ARCHITECTURE.md`
**Reasoning:** Health should be computed once during the vault decrypt pass and surfaced on Home for awareness, with Health tab focused on triage/fix; reuse must reflect actual duplicate values.

## [2026-08-15] Initial architecture captured

**Summary:** Baseline snapshot of Nucleus as implemented: Flutter + Riverpod (`StateNotifier`) + go_router client that uses Supabase Auth, `profiles`, and `vault_items` with Argon2id/AES-256-GCM zero-knowledge encryption, in-memory DEK sessions, biometric DEK cache, vault CRUD for four item types, profile/avatars, settings (theme, auto-lock, reveal grace, change master password), password generator, and health scoring. No use-case layer, no Riverpod codegen, no offline sync.
**Files:** N/A (baseline)
**Reasoning:** N/A (baseline)
