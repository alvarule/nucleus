# Changelog

## [2026-09-03] Vault Home — sticky folders, multi-select move, jump fix

**Summary:** Home uses `SliverStickyHeader` (`flutter_sticky_header`) so folder headers stick and push in the same scroll column. Long-press multi-select + bulk move via folder picker (`FolderPickerSelection.destination` vs `current` on the form). Jump-to-folder targets header keys on item-level slivers.
**Files:** `lib/features/vault/presentation/pages/vault_home_page.dart`, `lib/features/vault/presentation/providers/vault_list_provider.dart`, `pubspec.yaml`, `docs/ARCHITECTURE.md`
**Reasoning:** Sticky headers improve orientation while scrolling; sliver layout avoids scrolling an entire section subtree; bulk move reuses encrypted `updateItem` and offline-friendly errors.

## [2026-09-01] Friendly offline connectivity errors

**Summary:** Added `connectivity_plus` preflight before Supabase calls. When offline or on network failures, the app shows a randomly chosen warm message from a curated list instead of raw socket/HTTP errors.
**Files:** `lib/core/network/connectivity_service.dart`, `lib/core/errors/offline_messages.dart`, `lib/core/errors/user_facing_error.dart`, `lib/core/errors/app_exception.dart`, repository impls, auth/vault controllers and pages, `test/offline_messages_test.dart`, `pubspec.yaml`, `docs/ARCHITECTURE.md`
**Reasoning:** Offline should feel human and reassuring; one central resolver keeps copy consistent across auth, vault, folders, and settings.

## [2026-09-01] Signup uses OTP only (no re-register Edge Function)

**Summary:** Removed `re-register-unconfirmed`. Signup is name + email via `signInWithOtp`; a second attempt with the same unconfirmed email sends another confirmation link. Confirmed accounts use login.
**Files:** `lib/features/auth/data/repositories/auth_repository_impl.dart`, `supabase/functions/re-register-unconfirmed/index.ts` (deleted), `docs/ARCHITECTURE.md`, `README.md`
**Reasoning:** No Auth password is stored at signup, so deleting unconfirmed users is unnecessary.

## [2026-09-01] Folders, Home sort/skeleton, email verification

**Summary:** Added single-level vault folders (grouped Home list, jump-to-folder scroll, long-press manage, form picker). Home sort (name / updated / created) persists locally. Initial Home load uses an animated full-page shimmer; health badges hide for fully healthy passwords. Signup is name+email only with confirmation deep link (`nucleus://login-callback`); master password and DEK/profile are created on `/vault-setup`. Edge Function `re-register-unconfirmed` lets an unconfirmed email start over.
**Files:** `supabase/migrations/002_folders.sql`, `supabase/functions/re-register-unconfirmed/index.ts`, `lib/features/vault/**`, `lib/features/auth/**`, `lib/router/app_router.dart`, `lib/main.dart`, `android/app/src/main/AndroidManifest.xml`, `lib/shared/widgets/vault_home_skeleton.dart`, `lib/core/di/providers.dart`, `docs/ARCHITECTURE.md`, `test/widget_test.dart`
**Reasoning:** Organize vault items without nested folders; keep Home retrieval fast with grouping + sort; avoid password-before-verify; reuse vault-setup for future OAuth.

## [2026-08-23] Password health — triage view, vault badges, reuse fix

**Summary:** Rebuilt password health per plan: shared session health scoring (`EvaluatePasswordHealth`), vault home badges, Health tab filters (All/Weak/Reused/Old), reused-password grouping, weak/reused listed above strong, Fix now flow via `/generator/fix` → edit, `password_changed_at` payload field, Settings password-age threshold (90/180 days). Fixed reuse detection to count duplicate passwords instead of marking all items when the vault has 2+ unique passwords.
**Files:** `lib/features/health/domain/**`, `lib/features/health/presentation/**`, `lib/features/vault/domain/password_field_helpers.dart`, `lib/features/vault/presentation/pages/vault_home_page.dart`, `lib/features/vault/presentation/pages/vault_item_detail_page.dart`, `lib/features/vault/presentation/pages/vault_item_form_page.dart`, `lib/features/generator/**`, `lib/features/settings/**`, `lib/router/app_router.dart`, `test/widget_test.dart`, `docs/ARCHITECTURE.md`
**Reasoning:** Health should be computed once during the vault decrypt pass and surfaced on Home for awareness, with Health tab focused on triage/fix; reuse must reflect actual duplicate values.

## [2026-08-15] Initial architecture captured

**Summary:** Baseline snapshot of Nucleus as implemented: Flutter + Riverpod (`StateNotifier`) + go_router client that uses Supabase Auth, `profiles`, and `vault_items` with Argon2id/AES-256-GCM zero-knowledge encryption, in-memory DEK sessions, biometric DEK cache, vault CRUD for four item types, profile/avatars, settings (theme, auto-lock, reveal grace, change master password), password generator, and health scoring. No use-case layer, no Riverpod codegen, no offline sync.
**Files:** N/A (baseline)
**Reasoning:** N/A (baseline)
