# Architecture

## Project Overview

Nucleus is a Flutter password manager (package name `nucleus`) that stores secrets as client-encrypted blobs in Supabase. The signed-in user’s master password both authenticates with Supabase Auth and derives a KEK that unwraps a per-user data encryption key (DEK) held in memory only while the vault is unlocked. Target users are people who want a local-feeling vault with cloud backup, without sending plaintext passwords, notes, or financial fields to the server.

## Folder Structure

```text
lib/ - Flutter application source
lib/main.dart - Process entry: env, Supabase, screenshot protection
lib/app.dart - Root MaterialApp: theme, router, lifecycle, activity tracking
lib/router/app_router.dart - GoRouter routes, auth/lock redirects, splash
lib/core/crypto/ - Argon2id KEK + AES-256-GCM wrap/payload crypto
lib/core/di/ - Shared Riverpod providers (client, repos, crypto, biometric store)
lib/core/errors/ - AppException, OfflineException, friendly offline copy, user-facing error resolver
lib/core/network/ - Connectivity probe before Supabase calls
lib/core/lifecycle/ - Resume-time auto-lock check (no lock on background)
lib/core/theme/ - Hand-authored Rose palette and ThemeData
lib/core/responsive/ - Width-based layout scale from a 390pt baseline
lib/features/auth/ - Login/signup, check-email, vault-setup, AuthController, AuthRepository
lib/features/unlock/ - Unlock page, in-memory vault session, device DEK store
lib/features/vault/ - Encrypted CRUD, folders, list/detail/form pages
lib/features/profile/ - Profile entity, repository impl, profile UI, avatars
lib/features/settings/ - Theme, auto-lock, reveal grace, change master password
lib/features/generator/ - Local password generator
lib/features/attachments/ - Encrypted file chunks in vault-files bucket
lib/features/mfa/ - Site authenticator + login TOTP (KEK-wrapped)
lib/shared/widgets/ - Shell, icons, fields, dialogs, option sheets, buttons, ui_list_group, sync chips, loader, sensitive-access gate
assets/animations/ - Brand Lottie used by VaultLoader
assets/icons/ - SVG icon set referenced by AppIcon
assets/avatars/ - Preset avatar path used by Profile (see pubspec)
supabase/migrations/001_initial.sql - profiles, vault_items, RLS, avatars bucket
supabase/migrations/003_attachments.sql - vault_attachments, document type, vault-files bucket
supabase/migrations/004_sync.sql - profiles.default_sync_mode, vault_items.sync_mode
supabase/migrations/005_mfa.sql - login TOTP columns, mfa_entries
pubspec.yaml - Dependencies and asset declarations
.env - SUPABASE_URL + publishable/anon key (loaded at startup)
```

## Features

### Authentication

* **What it does:** Signup is name + email only (`signInWithOtp` magic/confirmation link). After the user opens `nucleus://login-callback`, `/vault-setup` sets the master password (`updateUser`), generates and wraps a DEK, writes `profiles`, caches the DEK for biometrics, and opens an unlocked session. Returning users sign in with email + master password; optional **App Login MFA** (`/login-totp`, TOTP or backup code) when `login_totp_enabled` on the profile. **Unlock** (`/unlock`, biometric or master password) does not require MFA when the user already has a Supabase session. Logout signs out Auth and clears the device DEK.
* **Files involved:**
  * `lib/features/auth/presentation/pages/login_page.dart`
  * `lib/features/auth/presentation/pages/signup_page.dart`
  * `lib/features/auth/presentation/pages/check_email_page.dart`
  * `lib/features/auth/presentation/pages/vault_setup_page.dart`
  * `lib/features/auth/presentation/providers/auth_controller.dart`
  * `lib/features/auth/domain/repositories/auth_repository.dart`
  * `lib/features/auth/data/repositories/auth_repository_impl.dart`
  * `lib/features/profile/data/repositories/profile_repository_impl.dart`
* **Key decisions:** Master password is never collected at signup. Auth password and vault master password are the same string, set at vault setup. `profiles` / DEK exist only after email verification. KDF params at wrap are `memory: 19456, iterations: 2, parallelism: 2`. Deep link scheme is `nucleus://login-callback`. Router: session + no profile → `/vault-setup`; session + profile + locked → `/unlock`.

### Vault session and unlock

* **What it does:** After Auth, the vault stays locked until the DEK is unwrapped (master password) or read from secure storage (biometrics). Lock drops the in-memory DEK; profile metadata can remain for the unlock screen. Auto-lock uses wall-clock inactivity (including time in background); app pause and screen-off do not lock immediately.
* **Files involved:**
  * `lib/features/unlock/presentation/pages/unlock_page.dart`
  * `lib/features/unlock/presentation/providers/vault_session_provider.dart`
  * `lib/features/unlock/data/biometric_unlock_store.dart`
  * `lib/core/lifecycle/vault_lifecycle_observer.dart`
  * `lib/app.dart`
  * `lib/router/app_router.dart`
* **Key decisions:** Master password is never stored. Biometric unlock stores a hex-encoded DEK in `FlutterSecureStorage` keyed by user id. Unlock auto-prompts biometrics once if a DEK exists. On `AppLifecycleState.resumed`, `onAppResumed` re-evaluates auto-lock (timers may not run while paused). Router redirects signed-in+profile+locked users to `/unlock`; signed-in with no profile to `/vault-setup`. `profileResolved` distinguishes “profile not loaded” from “no profile row”. GoRouter refresh listens to session status, profile resolution, and Auth events so reveal-grace updates do not drop `extra` on edit routes.

### Encrypted vault

* **What it does:** CRUD for five item types (`password`, `bank_account`, `atm_card`, `note`, `document`). Field maps are JSON-encrypted with the DEK before insert/update. Items may belong to a single-level folder (`folder_id`, null = Uncategorized). **Sync:** `profiles.default_sync_mode` sets the default for new items; each row has `sync_mode` (`cloud` | `local`). Local-only items live in Drift (`LocalVaultDatabase`); cloud items in Supabase. Composite `VaultRepositoryImpl` merges lists by id. Item form **Sync to Cloud** is draft until **Save** (promote/demote on save). Settings default change uses two steps (`vault_sync_dialogs.dart`): confirm default, then optional bulk upload of local-only items or bulk removal from cloud. `CloudSyncExclusionStore` remains for legacy “leave in cloud” exclusions on list only.
* **Files involved:**
  * `lib/features/vault/domain/entities/vault_item.dart`
  * `lib/features/vault/domain/entities/vault_folder.dart`
  * `lib/features/vault/domain/folder_sections.dart`
  * `lib/features/vault/domain/vault_sort.dart`
  * `lib/features/vault/domain/repositories/vault_repository.dart`
  * `lib/features/vault/domain/repositories/folder_repository.dart`
  * `lib/features/vault/data/repositories/cloud_vault_repository.dart`
  * `lib/features/vault/data/repositories/local_vault_repository.dart`
  * `lib/features/vault/data/local/local_vault_database.dart`
  * `lib/features/vault/presentation/widgets/vault_sync_dialogs.dart`
  * `lib/features/vault/data/repositories/folder_repository_impl.dart`
  * `lib/features/vault/presentation/providers/vault_list_provider.dart`
  * `lib/features/vault/presentation/pages/vault_home_page.dart`
  * `lib/features/vault/presentation/pages/vault_item_detail_page.dart`
  * `lib/features/vault/presentation/pages/vault_item_form_page.dart`
  * `lib/features/vault/presentation/widgets/folder_sheets.dart`
  * `lib/features/vault/domain/password_field_helpers.dart`
  * `lib/shared/widgets/vault_home_skeleton.dart`
* **Key decisions:** AES-GCM additional authenticated data is `id:itemType` so ciphertext cannot be moved between rows. Folder names are plaintext metadata. Delete folder uses ON DELETE SET NULL (items become Uncategorized). New items default to Uncategorized. `VaultListNotifier` listens to vault session: clears decrypted rows on lock, calls `refresh()` when the vault unlocks; `refresh()` no-ops while locked without wiping cached list state. Home uses `CustomScrollView` with `SliverStickyHeader` per folder (`flutter_sticky_header`) so headers stick and push in one scroll column, plus per-item `SliverList` children. Folder headers are rounded `surface` cards with a primary left rail, larger folder icon and title, and a muted “N items” + chevron; sticky push and jump-to-folder are unchanged. Jump-to-folder keys a zero-height sentinel before each sticky section and scrolls by summing preceding slivers’ `scrollExtent` (not `getOffsetToReveal`, which subtracts sticky `maxScrollObstructionExtent` and undershoots when jumping down the list). Home omits folder sections with zero visible items (All and type chips); move/form pickers still list every folder. Search and type chips sit in an opaque `Material` above a clipped list so tiles cannot paint through the filters. `showFolderPickerSheet` uses `FolderPickerSelection.destination` for bulk move (no highlight) vs `.current` on the item form. Long-press on items enters multi-select; the app bar swaps to close + count + compact Move (avoids a second bar stacked on the shell tab bar). Move uses the folder picker and bulk-updates `folder_id`. Home sort is device-local SharedPreferences; the picker is `showAppOptionSheet` (rose selected rows, icons, same padding as Settings). Initial Home load uses a full-page shimmer (`VaultHomeSkeleton`); pull-to-refresh does not. Health badges on Home hide when `primaryFlag == fine`. Edit route `/vault/edit/:id` requires `extra` as a `VaultItem` or a map with `item` + optional `prefill`. After save, the app `go`s to `/home` then `push`es detail. Password items store `password_changed_at` in the encrypted payload. The add-item sheet is scroll-controlled with taller type tiles so the 2-column grid does not overflow.

### Offline connectivity

* **What it does:** Before Supabase calls, repositories check `connectivity_plus`. When offline (or on a transport failure), UI shows a randomly chosen friendly line from `offline_messages.dart` instead of raw socket/HTTP errors.
* **Files involved:**
  * `lib/core/network/connectivity_service.dart`
  * `lib/core/errors/offline_messages.dart`
  * `lib/core/errors/user_facing_error.dart`
  * `lib/core/errors/app_exception.dart` (`OfflineException`)
  * Repository impls under `auth`, `profile`, and `vault` data layers
* **Key decisions:** Preflight in repositories for fast failure; `userFacingErrorMessage` centralizes mapping in controllers/pages. Unlock still shows “Wrong master password” for crypto failures when online.

### Sensitive reveal and copy

* **What it does:** Passwords and selected financial fields stay masked until the user passes biometrics or a master-password sheet. A configurable reveal-grace window can skip re-auth. Copy from the home list uses the same gate.
* **Files involved:**
  * `lib/shared/widgets/sensitive_access.dart`
  * `lib/shared/widgets/masked_secret_field.dart`
  * `lib/shared/widgets/vault_text_field.dart`
  * `lib/features/unlock/presentation/providers/vault_session_provider.dart`
  * `lib/features/settings/domain/security_timeouts.dart`
* **Key decisions:** `confirmMasterPasswordForReveal` unwraps the DEK without flipping session status to `unlocking` (that would trigger router redirect) and does not lock on failure. Form unmask on **edit** calls the gate; new items do not. Generator copy does not use this gate (the value is generated locally, not loaded from the vault).

### Profile

* **What it does:** Edit display name; email is read-only. Avatar is a preset PNG (`assets/avatars/{id}.png`, ids 1–60 in the picker) or a custom gallery upload to the private `avatars` storage bucket, shown via a signed URL.
* **Files involved:**
  * `lib/features/profile/presentation/pages/profile_page.dart`
  * `lib/features/profile/presentation/widgets/avatar_widget.dart`
  * `lib/features/profile/domain/entities/user_profile.dart`
  * `lib/features/profile/data/repositories/profile_repository_impl.dart`
* **Key decisions:** Profile does not own theme, lock, or logout. Custom avatars are stored as `{userId}/{timestamp}.jpg`. Signed URLs expire after one hour.

### Settings

* **What it does:** Light/dark/system appearance (persisted on `profiles.theme_preference`), **default sync mode for new items** (cloud vs local on profile), **login two-factor (TOTP)** setup at `/settings/login-mfa-setup`, auto-lock timeout, reveal-grace timeout, password age threshold (90 or 180 days for Health “Old” filter), change master password, lock now, logout.
* **Files involved:**
  * `lib/features/settings/presentation/pages/settings_page.dart`
  * `lib/features/settings/presentation/pages/change_master_password_page.dart`
  * `lib/features/settings/presentation/pages/login_mfa_setup_page.dart`
  * `lib/features/settings/presentation/providers/theme_preference_provider.dart`
  * `lib/features/settings/presentation/providers/security_preference_provider.dart`
  * `lib/features/settings/presentation/providers/change_master_password_controller.dart`
  * `lib/features/settings/domain/security_timeouts.dart`
* **Key decisions:** Auto-lock, reveal-grace, and password-age threshold live in `SharedPreferences` on device, not in Supabase. Theme is applied locally first, then written to the profile. Master-password change re-wraps the **same** DEK (items are not re-encrypted). Wrap is persisted before Auth `updatePassword`; if Auth fails, the previous wrap is rolled back best-effort. Biometric DEK remains valid because the DEK bytes do not change.

### Password generator

* **What it does:** Generates a password locally (length 8–64, charset toggles) with at least one character from each selected set, then shuffle. Can copy, save as a new vault item (`/vault/new?type=password` with `extra`), or continue a **fix flow** from Health/detail (`/generator/fix` with `VaultItem` extra → edit form with generated password).
* **Files involved:**
  * `lib/features/generator/domain/password_generator.dart`
  * `lib/features/generator/presentation/pages/generator_page.dart`
* **Key decisions:** Generation uses `Random.secure()`. Prefill and fix-flow context depend on GoRouter `extra`, which is why router refresh is restricted.

### Password health

* **What it does:** Computes weak / reused / old / fine status once per session from the decrypted vault list (`EvaluatePasswordHealth` in health domain). Vault home shows at-a-glance badges; the Health tab is a triage/fix view with All/Weak/Reused/Old filters (tappable stat shortcuts), reused-password grouping, weak/reused items listed above strong ones, and **Fix now** (generator → edit same item → save lands on `home → detail`). Reuse is detected by counting duplicate password values across items.
* **Files involved:**
  * `lib/features/health/domain/password_health_checker.dart`
  * `lib/features/health/domain/use_cases/evaluate_password_health.dart`
  * `lib/features/health/domain/password_health_display.dart`
  * `lib/features/health/domain/entities/item_health_snapshot.dart`
  * `lib/features/health/presentation/providers/password_health_provider.dart`
  * `lib/features/health/presentation/pages/health_page.dart`
  * `lib/features/health/presentation/widgets/health_badge.dart`
  * `lib/features/vault/domain/password_field_helpers.dart`
* **Key decisions:** Health logic lives in `health/domain` and is consumed by both `health` and `vault` presentation via `passwordHealthProvider`. `password_changed_at` (encrypted payload field) drives the Old filter; missing values fall back to `updated_at`. List rows use `{label} — {username|url host}` with date disambiguation on collision. Fix flow uses root overlay `/generator/fix` so the Generator tab stays clean.

### Attachments and documents

* **What it does:** Client-encrypted files in private `vault-files` bucket (`vault_attachments` metadata). Chunks use DEK + AAD `attachment_id:chunk_index`; metadata JSON is DEK-encrypted. `document` item type (label, notes, requires ≥1 attachment). `AttachmentsSection` on vault form and detail (open/download on detail); pending files on create upload after save. Uploads require cloud sync mode.
* **Files involved:**
  * `lib/features/attachments/**`
  * `lib/shared/widgets/attachments_section.dart`
  * `supabase/migrations/003_attachments.sql`
* **Key decisions:** Plaintext > 5 MB splits into ~4 MB chunks before encrypt. Local-only vault items cannot upload attachments until synced to cloud. **Open** decrypts to a temp file and uses a platform channel (`ACTION_VIEW` + chooser on Android, document interaction on iOS), not the share sheet. Form and detail use the same labeled + `UiGroupedCard` chrome as folder/sync/fields: file rows with rose icon tiles, tap to open, compact download; **Add files** is a nav row in the card (not a header plus).

### MFA (site authenticator + App Login MFA)

* **What it does:** **App Login MFA** — optional second step on **full sign-in only** (`/login` → `/login-totp`); app-generated enrollment QR at `/settings/app-login-mfa/setup`; KEK-wrapped TOTP secret and hashed backup codes on `profiles`; one-time backup display with regenerate flow on manage screen; disable requires master password + TOTP or backup. **Unlock** never prompts for MFA. **MFA tab** — `mfa_entries` cloud-synced; home-style search on issuer and account; QR scan with framed overlay (`OtpAuthUri` parses issuer/account/secret); manual add requires issuer + secret; grouped list; detail with live TOTP, editable account, copy, confirmed delete; add via `/mfa/new` or `/mfa/scan`.
* **Files involved:**
  * `lib/features/mfa/**` (`login_mfa_service.dart`)
  * `lib/features/settings/presentation/pages/app_login_mfa_pages.dart`
  * `lib/features/auth/presentation/pages/login_totp_page.dart`
  * `supabase/migrations/005_mfa.sql`, `006_login_mfa_backup.sql`
* **Key decisions:** Site MFA uses vault DEK; App Login MFA uses KEK only. Backup codes stored as SHA-256 hashes; shown once at setup/regenerate (not re-viewable). **Save file** uses `FilePicker.saveFile` (user-chosen location), same as attachment download. Incomplete sign-in MFA persists only for the current process (in-memory password + store flag); after restart, auth is reset and user signs in from email/password again. Unlock and biometrics refuse while sign-in MFA is pending in-session. Login TOTP verification spans submit→verify time steps plus ±2. Account recovery without authenticator and backup codes is an acknowledged ZK gap (no email reset).

### Theming, shell, and platform hardening

* **What it does:** Rose vault light/dark themes, bottom-nav shell (Home, MFA, Generator, Health, Settings), scaled layout, SVG icons, Lottie loader, and screenshot leakage protection at process start.
* **Files involved:**
  * `lib/core/theme/app_theme.dart`
  * `lib/core/theme/app_colors.dart`
  * `lib/shared/widgets/app_shell.dart`
  * `lib/shared/widgets/app_icon.dart`
  * `lib/shared/widgets/vault_loader.dart`
  * `lib/core/responsive/scale.dart`
  * `lib/main.dart`
* **Key decisions:** Theme is an explicit `ColorScheme` plus `AppColors` extension, not `ColorScheme.fromSeed`. Shell `PopScope` intercepts back only while the shell is the top route: non-home tabs go to Home; Home requires back twice within 2s to `SystemNavigator.pop`. `ScreenProtector.protectDataLeakageOn()` is wrapped in try/catch for unsupported platforms/tests. If `.env` keys are missing or placeholders, Supabase is still initialized with a dummy URL/key so the UI can boot.

## Data Flow

### App boot

```text
main() → dotenv → Supabase.initialize → ScreenProtector → ProviderScope(NucleusApp)
NucleusApp → goRouter → /splash
splash → if Auth user: loadProfile → /vault-setup if no profile else /unlock
       → else: /login
```

GoRouter then keeps signed-out users on `/login`|`/signup`|`/check-email`, signed-in users without a profile on `/vault-setup`, and signed-in+locked users on `/unlock`.

### Sign up

```text
SignupPage (name + email) → AuthController.requestSignupLink
  → signInWithOtp (magic/confirmation link)
  → /check-email (resend / back to signup)
User opens email link → nucleus://login-callback → session
  → loadProfile (null) → /vault-setup
VaultSetupPage → updateUser(password) → generateDek + wrapDek
  → ProfileRepository.createProfile
  → BiometricUnlockStore.saveDek
  → VaultSessionNotifier.openUnlockedSession
  → /home
```

### Sign in

```text
LoginPage → AuthController.signIn
  → AuthRepository.signInWithPassword
  → VaultSessionNotifier.unlockWithPassword
  → ProfileRepository.getProfile
  → VaultCryptoService.unwrapDek
  → BiometricUnlockStore.saveDek
  → unlocked session → /home
```

### Unlock (already signed in)

```text
Password: UnlockPage → unlockWithPassword → unwrapDek → in-memory DEK
Biometrics: local_auth → readDek(userId) → in-memory DEK (no KDF)
```

### List / create / update vault items

```text
UI → VaultListNotifier / form
  → VaultRepository (requires session.dek)
  → AES-GCM encrypt/decrypt with AAD id:type
  → Supabase table vault_items (ciphertext + nonce only)
```

Search, type chips, folder grouping, and sort run in `VaultListState` after decrypt.

### Password health (session)

```text
vaultListProvider refresh (decrypt all items)
  → passwordHealthProvider watches items + password-age threshold
  → EvaluatePasswordHealth (count duplicates, strength, age)
  → Vault home badges + Health tab triage UI read same map
```

Fix now: Health or detail → `/generator/fix` (extra: VaultItem) → `/vault/edit/:id` (extra: item + prefill password) → save → `go /home` + `push /vault/:id`.

### Reveal or copy a secret

```text
UI → ensureSensitiveAccess
  → if canRevealSecrets: allow
  → else gateForReveal (biometrics)
  → else master-password sheet → confirmMasterPasswordForReveal (unwrap check only)
  → grantRevealGrace + touchActivity
```

### Change master password

```text
ChangeMasterPasswordPage → ChangeMasterPasswordController
  → unwrapDek(current) and compare to session DEK
  → rewrapDek(new password)
  → ProfileRepository.updateProfile (new wrap)
  → Auth signIn(current) + updatePassword(new)
  → on Auth failure: restore previous wrap
  → session.setProfile (DEK unchanged)
```

### Lock and logout

```text
Inactivity timer (SharedPreferences auto-lock, wall-clock) → lock
App resumed → re-check inactivity (same rules)
Settings “Lock vault now” → lock → /unlock
Logout → clearDek + Auth.signOut → empty session → /login
```

Pointer-down on the root `Listener` calls `touchActivity` to reset the inactivity clock.

## Decisions Log

| Decision | Reasoning | Date/Context |
| -------- | --------- | ------------ |
| Client-side Argon2id + AES-256-GCM; server stores wrap + ciphertext only | Zero-knowledge relative to Supabase: plaintext never leaves the device | Current implementation |
| Signup/change-password KDF `19456 / 2 / 2` instead of `KdfParams` defaults `65536 / 3 / 4` | Lower Argon2 memory/iterations for mobile wrap time | Current implementation |
| Same string for Auth password and vault master password | One credential to remember; unwrap uses Auth password | Current implementation |
| Device stores DEK (hex) after successful unwrap, never the master password | Enables biometric unlock without persisting the password | Current implementation |
| GoRouter refresh on lock **status** and Auth events only | Reveal-grace must not drop `extra` on edit/new routes | Current implementation |
| AES-GCM AAD = `itemId:itemType` | Bind ciphertext to its row/type | Current implementation |
| Change master password re-wraps DEK; does not re-encrypt items | DEK is unchanged, so vault rows and biometric DEK stay valid | Current implementation |
| Persist new wrap before Auth password update, rollback wrap on Auth failure | Avoids Auth password and wrap diverging | Current implementation |
| Auto-lock / reveal-grace in SharedPreferences; theme on `profiles` | Timers are device-local; appearance should follow the user | Current implementation |
| Auto-lock on wall-clock inactivity only (not on `paused`); resume re-check | Lets system pickers (attachments, gallery) background the app without losing the DEK session; DEK may stay in memory until timeout | 2026-09-03 |
| Placeholder Supabase init when `.env` is unset | UI can start in tests/dev; real Auth/vault calls fail until configured | Current implementation |
| Hand-authored `AppColors` / `ColorScheme`, not `fromSeed` | Keep brand rose exact | Current implementation |
| Signup is name+email OTP; master password set on `/vault-setup` after confirm | Avoid collecting a password before the email is verified; same setup path can later serve Google OAuth | 2026-09-01 |
| Single-level plaintext `vault_folders`; items `folder_id` ON DELETE SET NULL | Organization without encrypting folder names or deleting items with a folder | 2026-09-01 |
| Home full-page shimmer until first vault fetch; no interaction during load | Prevents search/sort racing an empty list | 2026-09-01 |
| Home health badge hidden when `primaryFlag` is fine | Surface only weak/reused/old on the list | 2026-09-01 |
| Drift local vault + composite repository; sync draft on form until Save; settings bulk opt-in | Cloud-first default; local-only has no cloud backup; destructive sync only after Save or explicit bulk Confirm | 2026-09-03 Phase 3; revised defer-save UX |
| Login TOTP on KEK; site MFA on DEK; MFA tab always cloud | One key system; codes survive device loss for authenticator entries | 2026-09-03 Phase 3 |
| App Login MFA only on `/login` sign-in, not on `/unlock` | Returning users with a session unlock with biometric/password only; MFA adds factor at credential entry | 2026-09-03 |
| Five-tab shell (MFA between Home and Generator) | Plan navigation; back behavior unchanged | 2026-09-03 Phase 3 |
| `ScreenProtector.protectDataLeakageOn()` at startup | Block screenshots/screen recording where the plugin supports it | Current implementation |
| `connectivity_plus` preflight + random friendly offline copy | Network calls fail fast offline; users see warm rotating messages instead of raw socket errors | 2026-09-01 |
