# Changelog

## [2026-09-03] Sign-in MFA gate after app restart; OTP pin fields

**Summary:** If sign-in MFA was interrupted (app restart), `loadProfile` calls `abandonIncompleteSignIn` (sign out, clear pending flags) instead of a combined master-password + MFA screen; user starts again at email/password then MFA in the same session.
**Files:** `lib/features/unlock/presentation/providers/vault_session_provider.dart`, `lib/router/app_router.dart`, `lib/features/auth/presentation/pages/login_totp_page.dart`, `docs/ARCHITECTURE.md`
**Reasoning:** Stale Supabase session without in-memory password should not offer unlock or a partial MFA re-auth screen.

## [2026-09-03] App Login MFA TOTP verification window

**Summary:** Login MFA TOTP checks span all 30s steps from user submit through verify (covers Argon2 master check + decrypt) plus ±2 steps; sign-in, disable, and regenerate pass `submittedAtMs`.
**Files:** `lib/features/mfa/data/login_mfa_service.dart`, `lib/features/auth/presentation/pages/login_totp_page.dart`, `lib/features/settings/presentation/pages/app_login_mfa_pages.dart`, `test/features/mfa/login_mfa_totp_verify_test.dart`, `docs/ARCHITECTURE.md`
**Reasoning:** Verification only at decrypt completion missed codes entered just before period rollover, especially after two slow KEK derivations on manage flows.

## [2026-09-03] MFA tab search

**Summary:** MFA list includes a search field matching Home (muted fill, search/close icons) that filters entries by issuer, account (username/email), and display title client-side.
**Files:** `lib/features/mfa/presentation/pages/mfa_list_page.dart`, `docs/ARCHITECTURE.md`
**Reasoning:** Same search UX as vault home for finding site authenticators quickly without server queries.

## [2026-09-03] MFA scan overlay, validation, account from QR, editable account

**Summary:** MFA QR scanner uses a dimmed frame overlay with corner brackets, torch toggle, and shared `otpauth` parsing (issuer, account, secret). Manual add requires issuer and secret; QR pre-fills account. Detail screen edits account in a surfaced card with save; list state updates via `replaceEntry`.
**Files:** `lib/features/mfa/domain/otpauth_uri.dart`, `lib/features/mfa/presentation/pages/mfa_scan_page.dart`, `lib/features/mfa/presentation/pages/mfa_new_page.dart`, `lib/features/mfa/presentation/pages/mfa_detail_page.dart`, `lib/features/mfa/domain/entities/mfa_entry.dart`, `lib/features/mfa/presentation/providers/mfa_list_provider.dart`, `lib/router/app_router.dart`, `docs/ARCHITECTURE.md`
**Reasoning:** Match modern scanner UX, enforce required fields, preserve username/email from standard QR labels, and allow account correction without re-scanning.

## [2026-09-03] MFA tab list and detail UI; delete syncs list

**Summary:** Deleting an authenticator from the detail screen now confirms, updates `mfaListProvider` (optimistic remove), and pops back to a refreshed list. MFA tab uses grouped list tiles with shield icon and chevron; detail shows countdown ring, spaced code, and copy action.
**Files:** `lib/features/mfa/presentation/pages/mfa_list_page.dart`, `lib/features/mfa/presentation/pages/mfa_detail_page.dart`, `lib/features/mfa/presentation/providers/mfa_list_provider.dart`, `docs/ARCHITECTURE.md`
**Reasoning:** List state was not notified on delete; UI aligned with vault home patterns for navigation affordance and polish.

## [2026-09-03] MFA QR account parsing, auto-save, loaders, flash icon

**Summary:** Fixed `otpauth://totp/...` parsing (label in path when host is `totp`). QR scan now creates the entry immediately with parsed account. MFA screens use `VaultLoader` / `VaultLoadingScaffold`; scanner torch uses `flash.svg`.
**Files:** `lib/features/mfa/domain/otpauth_uri.dart`, `lib/features/mfa/presentation/pages/mfa_scan_page.dart`, `lib/features/mfa/presentation/pages/mfa_list_page.dart`, `lib/features/mfa/presentation/pages/mfa_detail_page.dart`, `lib/features/mfa/presentation/pages/mfa_new_page.dart`, `assets/icons/flash.svg`, `test/features/mfa/otpauth_uri_test.dart`, `docs/CHANGELOG.md`
**Reasoning:** Standard authenticator QRs were not populating account because Dart puts `totp` in the host, not as a second path segment.

## [2026-09-03] App Login MFA wizard and backup codes

**Summary:** Replaced manual login MFA setup with a guided wizard (re-auth, QR enrollment, verify, one-time backup codes). MFA applies only on full sign-in (`/login-totp`); unlock stays biometric or master password only. Manage screen for disable and backup regeneration; master password change re-wraps login MFA blobs.
**Files:** `lib/features/mfa/data/login_mfa_service.dart`, `lib/features/settings/presentation/pages/app_login_mfa_pages.dart`, `lib/features/auth/presentation/pages/login_totp_page.dart`, `lib/features/settings/presentation/providers/change_master_password_controller.dart`, `lib/features/profile/**`, `lib/router/app_router.dart`, `supabase/migrations/006_login_mfa_backup.sql`, `pubspec.yaml`, `docs/ARCHITECTURE.md`
**Reasoning:** Clear enrollment UX and recovery codes without weakening the existing unlock flow for returning users.

## [2026-09-03] Attachment open with system apps

**Summary:** Tapping **Open** on an attachment decrypts to a temp file and launches the system viewer (“Open with” on Android via `ACTION_VIEW` + chooser; Open In on iOS) instead of the share sheet. MIME types are resolved from the filename when opening and when picking files. Uses an in-app platform channel (not `open_filex`, which fails on AGP 9).
**Files:** `lib/shared/widgets/attachments_section.dart`, `lib/core/platform/open_local_file.dart`, `android/app/src/main/kotlin/com/nucleus/nucleus/MainActivity.kt`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/file_paths.xml`, `ios/Runner/AppDelegate.swift`, `pubspec.yaml`, `docs/ARCHITECTURE.md`
**Reasoning:** Share was the wrong UX for viewing files; viewers need correct MIME and an VIEW intent.

## [2026-09-03] Sync-to-cloud defer Save and settings bulk

**Summary:** Per-item **Sync to Cloud** on the vault form updates draft state only; upload to cloud or delete from cloud runs on **Save**. Changing the Settings default is two-step: confirm default, then optional bulk upload of all local-only items (local→cloud default) or bulk delete from cloud (cloud→local default). Declining bulk updates the profile default only. Removed per-item toggle-time strategy dialogs and “leave in cloud” on edit.
**Files:** `lib/features/vault/presentation/pages/vault_item_form_page.dart`, `lib/features/vault/presentation/widgets/vault_sync_dialogs.dart`, `lib/features/settings/presentation/pages/settings_page.dart`, `lib/features/vault/domain/repositories/vault_repository.dart`, `lib/features/vault/data/repositories/vault_repository_impl.dart`, `lib/features/vault/data/repositories/cloud_vault_repository.dart`, `lib/features/vault/domain/entities/vault_bulk_sync_result.dart`, `docs/ARCHITECTURE.md`, `.cursor/plans/nucleus_flutter_app_fe530d03.plan.md`, `.cursor/plans/nucleus_phase_3_plan_509c4ea1.plan.md`
**Reasoning:** Users expected sync side effects only when saving an item or explicitly confirming bulk migration, not when toggling the switch.

## [2026-09-03] Attachments UX and sync toggle

**Summary:** Detail page lists attachments with open and download actions. Create flow supports pending attachments (upload after save). Documents require at least one attachment and cloud sync. Sync uses a “Sync to Cloud” switch on item form and Settings; mode-change dialogs use radio options with Confirm/Cancel. Open uses `share_plus` (no `open_filex` — incompatible with AGP 9 in this project).
**Files:** `lib/shared/widgets/attachments_section.dart`, `lib/features/attachments/domain/entities/pending_attachment.dart`, `lib/features/vault/presentation/pages/vault_item_detail_page.dart`, `lib/features/vault/presentation/pages/vault_item_form_page.dart`, `lib/features/vault/presentation/widgets/vault_sync_dialogs.dart`, `lib/features/settings/presentation/pages/settings_page.dart`, `pubspec.yaml`, `docs/ARCHITECTURE.md`
**Reasoning:** Attachments were not shown on detail; create flow blocked documents; sync sheets confirmed on first tap.

## [2026-09-03] Auto-lock only (no background lock)

**Summary:** Removed vault lock on app pause/screen off. The DEK session stays unlocked while backgrounded (e.g. file picker for attachments) until the Settings auto-lock timer expires (wall-clock inactivity, including background) or the user taps Lock vault now. On resume, the session re-checks the timer because OS may throttle timers while paused.
**Files:** `lib/core/lifecycle/vault_lifecycle_observer.dart`, `lib/features/unlock/presentation/providers/vault_session_provider.dart`, `lib/app.dart`, `lib/features/settings/domain/security_timeouts.dart`, `docs/ARCHITECTURE.md`, `.cursor/plans/nucleus_flutter_app_fe530d03.plan.md`
**Reasoning:** Immediate background lock aborted attachment and gallery flows; auto-lock already enforced inactivity with a user-configurable timeout.

## [2026-09-03] Vault home empty after unlock

**Summary:** Fixed vault list showing zero items after unlock or when `refresh()` ran while locked: skip refresh without wiping state, clear list only when the session locks, and reload when the vault unlocks. Fixed local-only item AAD using the wrong id on create.
**Files:** `lib/features/vault/presentation/providers/vault_list_provider.dart`, `lib/features/vault/data/repositories/local_vault_repository.dart`, `docs/CHANGELOG.md`
**Reasoning:** `refresh()` cleared items on a locked no-op; Home did not always refetch after unlock when the shell stayed mounted.

## [2026-09-03] Vault list load resilience

**Summary:** Cloud/local list skips undecryptable rows instead of failing the whole fetch; folder and item loads are independent so items still apply if folders fail; items with missing folder metadata show under Uncategorized; Home shows a retry banner on load errors.
**Files:** `lib/features/vault/data/repositories/cloud_vault_repository.dart`, `lib/features/vault/data/repositories/local_vault_repository.dart`, `lib/features/vault/data/repositories/vault_repository_impl.dart`, `lib/features/vault/domain/folder_sections.dart`, `lib/features/vault/presentation/providers/vault_list_provider.dart`, `lib/features/vault/presentation/pages/vault_home_page.dart`, `docs/CHANGELOG.md`
**Reasoning:** One bad ciphertext or a folders API failure produced an empty Home list despite rows in Supabase; orphaned `folder_id` values were omitted from all sections.

## [2026-09-03] Phase 3 — sync, attachments, MFA, five-tab nav

**Summary:** Added local/cloud vault sync (Drift + composite repository, profile default and per-item `sync_mode`, Settings and item form with confirm dialogs). Encrypted attachments (`vault_attachments`, `vault-files` bucket), `document` item type, and `AttachmentsSection`. Login TOTP (KEK-wrapped) with `/login-totp`; site authenticator (`mfa_entries`) and MFA tab. Bottom nav: Home · MFA · Generator · Health · Settings. Migrations `003`–`005`.
**Files:** `supabase/migrations/003_attachments.sql`, `004_sync.sql`, `005_mfa.sql`, `lib/features/vault/data/local/**`, `lib/features/vault/data/repositories/*`, `lib/features/attachments/**`, `lib/features/mfa/**`, `lib/features/auth/presentation/pages/login_totp_page.dart`, `lib/features/settings/presentation/pages/login_mfa_setup_page.dart`, `lib/shared/widgets/attachments_section.dart`, `lib/router/app_router.dart`, `lib/shared/widgets/app_shell.dart`, `pubspec.yaml`, `docs/ARCHITECTURE.md`
**Reasoning:** Phase 3 plan: optional local-only items, encrypted documents, login MFA without changing unlock, and a dedicated authenticator tab while keeping zero-knowledge crypto on one DEK.

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
