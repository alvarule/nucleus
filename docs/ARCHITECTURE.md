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
lib/core/errors/ - AppException / AuthFailure / CryptoException / VaultException
lib/core/lifecycle/ - Background lock observer
lib/core/theme/ - Hand-authored Rose palette and ThemeData
lib/core/responsive/ - Width-based layout scale from a 390pt baseline
lib/features/auth/ - Login/signup UI, AuthController, AuthRepository
lib/features/unlock/ - Unlock page, in-memory vault session, device DEK store
lib/features/vault/ - Encrypted CRUD, list/detail/form pages
lib/features/profile/ - Profile entity, repository impl, profile UI, avatars
lib/features/settings/ - Theme, auto-lock, reveal grace, change master password
lib/features/generator/ - Local password generator + health scoring helpers
lib/features/health/ - Health tab UI over decrypted password items
lib/shared/widgets/ - Shell, icons, fields, loader, sensitive-access gate
assets/animations/ - Brand Lottie used by VaultLoader
assets/icons/ - SVG icon set referenced by AppIcon
assets/avatars/ - Preset avatar path used by Profile (see pubspec)
supabase/migrations/001_initial.sql - profiles, vault_items, RLS, avatars bucket
pubspec.yaml - Dependencies and asset declarations
.env - SUPABASE_URL + publishable/anon key (loaded at startup)
```

## Features

### Authentication

* **What it does:** Email + master-password sign-up and sign-in via Supabase Auth. Sign-up also generates a DEK, wraps it, writes a `profiles` row, caches the DEK for biometrics, and opens an unlocked session. Logout signs out Auth and clears the device DEK.
* **Files involved:**
  * `lib/features/auth/presentation/pages/login_page.dart`
  * `lib/features/auth/presentation/pages/signup_page.dart`
  * `lib/features/auth/presentation/providers/auth_controller.dart`
  * `lib/features/auth/domain/repositories/auth_repository.dart`
  * `lib/features/auth/data/repositories/auth_repository_impl.dart`
  * `lib/features/profile/data/repositories/profile_repository_impl.dart`
* **Key decisions:** The Auth password and vault master password are the same string. After `signUp`, if email confirmation leaves `currentUserId` null, the controller immediately `signIn`s. KDF params used at signup are `memory: 19456, iterations: 2, parallelism: 2` (not the `KdfParams` class defaults). `ProfileRepository` is declared in the auth domain file because profile creation is part of signup.

### Vault session and unlock

* **What it does:** After Auth, the vault stays locked until the DEK is unwrapped (master password) or read from secure storage (biometrics). Lock drops the in-memory DEK; profile metadata can remain for the unlock screen. Foreground inactivity auto-lock and background pause lock are both implemented.
* **Files involved:**
  * `lib/features/unlock/presentation/pages/unlock_page.dart`
  * `lib/features/unlock/presentation/providers/vault_session_provider.dart`
  * `lib/features/unlock/data/biometric_unlock_store.dart`
  * `lib/core/lifecycle/vault_lifecycle_observer.dart`
  * `lib/app.dart`
  * `lib/router/app_router.dart`
* **Key decisions:** Master password is never stored. Biometric unlock stores a hex-encoded DEK in `FlutterSecureStorage` keyed by user id. Unlock auto-prompts biometrics once if a DEK exists. Lifecycle lock runs on `AppLifecycleState.paused` but skips while a biometric prompt is showing (`isAuthenticating`). Router redirects signed-in+locked users to `/unlock`, not `/login`. GoRouter refresh listens only to session **status** changes so reveal-grace updates do not rebuild routes.

### Encrypted vault

* **What it does:** CRUD for four item types (`password`, `bank_account`, `atm_card`, `note`). Field maps are JSON-encrypted with the DEK before insert/update. The home list searches and filters client-side after decrypt.
* **Files involved:**
  * `lib/features/vault/domain/entities/vault_item.dart`
  * `lib/features/vault/domain/repositories/vault_repository.dart`
  * `lib/features/vault/data/repositories/vault_repository_impl.dart`
  * `lib/features/vault/presentation/providers/vault_list_provider.dart`
  * `lib/features/vault/presentation/pages/vault_home_page.dart`
  * `lib/features/vault/presentation/pages/vault_item_detail_page.dart`
  * `lib/features/vault/presentation/pages/vault_item_form_page.dart`
* **Key decisions:** AES-GCM additional authenticated data is `id:itemType` so ciphertext cannot be moved between rows. Edit route `/vault/edit/:id` requires `extra` as a `VaultItem`; missing extra shows “Missing item”. After save, the app `go`s to `/home` then `push`es detail so back returns to the list. `VaultItemRecord` exists as a ciphertext-shaped model but the repository maps rows directly to `VaultItem`.

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

* **What it does:** Light/dark/system appearance (persisted on `profiles.theme_preference`), auto-lock timeout, reveal-grace timeout, change master password, lock now, logout.
* **Files involved:**
  * `lib/features/settings/presentation/pages/settings_page.dart`
  * `lib/features/settings/presentation/pages/change_master_password_page.dart`
  * `lib/features/settings/presentation/providers/theme_preference_provider.dart`
  * `lib/features/settings/presentation/providers/security_preference_provider.dart`
  * `lib/features/settings/presentation/providers/change_master_password_controller.dart`
  * `lib/features/settings/domain/security_timeouts.dart`
* **Key decisions:** Auto-lock and reveal-grace live in `SharedPreferences` on device, not in Supabase. Theme is applied locally first, then written to the profile. Master-password change re-wraps the **same** DEK (items are not re-encrypted). Wrap is persisted before Auth `updatePassword`; if Auth fails, the previous wrap is rolled back best-effort. Biometric DEK remains valid because the DEK bytes do not change.

### Password generator

* **What it does:** Generates a password locally (length 8–64, charset toggles) with at least one character from each selected set, then shuffle. Can copy or open `/vault/new?type=password` with the value in `extra`.
* **Files involved:**
  * `lib/features/generator/domain/password_generator.dart`
  * `lib/features/generator/presentation/pages/generator_page.dart`
* **Key decisions:** Generation uses `Random.secure()`. Prefill depends on GoRouter `extra`, which is why router refresh is restricted.

### Password health

* **What it does:** Scores decrypted `password`-type items for length, charset, a small common-password list, and a reuse flag. Shows counts and a per-item row. Does not navigate to detail.
* **Files involved:**
  * `lib/features/health/presentation/pages/health_page.dart`
  * `lib/features/generator/domain/password_generator.dart`
* **Key decisions:** Health reads whatever is already in `vaultListProvider` (decrypted in memory). The UI passes a **Set** of unique passwords into `evaluate`. The reuse condition is `count == password > 1` (impossible on a Set) **or** `set.contains(password) && set.length > 1`. With that call site, any password is marked reused whenever the vault has two or more distinct passwords.

### Theming, shell, and platform hardening

* **What it does:** Rose vault light/dark themes, bottom-nav shell (Home, Generator, Health, Settings), scaled layout, SVG icons, Lottie loader, and screenshot leakage protection at process start.
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
splash → if Auth user: loadProfile → /unlock
       → else: /login
```

GoRouter then keeps signed-out users on `/login`|`/signup` and signed-in+locked users on `/unlock`.

### Sign up

```text
SignupPage → AuthController.signUp
  → AuthRepository.signUp (+ signIn if session missing)
  → VaultCryptoService.generateDek + wrapDek(master password)
  → ProfileRepository.createProfile (wrapped DEK, salt, kdf_params)
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

Search and type filters run in `VaultListState.visible` after decrypt.

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
Background paused (not during biometric) → VaultSessionNotifier.lock (drop DEK)
Inactivity timer (SharedPreferences auto-lock) → lock
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
| Lock on `paused`, skip while `isAuthenticating` | Background lock without killing the biometric sheet | Current implementation |
| Placeholder Supabase init when `.env` is unset | UI can start in tests/dev; real Auth/vault calls fail until configured | Current implementation |
| Hand-authored `AppColors` / `ColorScheme`, not `fromSeed` | Keep brand rose exact | Current implementation |
| Feature folders with domain contracts + data impls; no use-case classes | Presentation talks to repositories through Riverpod `StateNotifier`s | Current implementation |
| `StatefulShellRoute` + Home-rooted back | Double-back exits only on Home; other tabs return Home first | Current implementation |
| `ScreenProtector.protectDataLeakageOn()` at startup | Block screenshots/screen recording where the plugin supports it | Current implementation |
