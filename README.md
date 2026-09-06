# Nucleus

Zero-knowledge password manager for Android (Flutter + Supabase).

## Development process

The architecture, data model, security model, UX flows, and feature scope for this project were designed by me. All code was implemented by Cursor against those specifications. Decisions such as the encryption scheme, database schema, navigation structure, and phased feature rollout were made ahead of implementation and are documented in this repository's architecture notes.

## Stack

- Flutter + Riverpod + go_router
- Clean Architecture (`features/*/domain|data|presentation`)
- Supabase Auth + Postgres + Storage
- Drift (local database for offline / local-only vault items)
- Argon2id + AES-256-GCM client-side encryption
- otp (TOTP) for login two-factor and the built-in site authenticator
- mobile_scanner for QR-based authenticator enrollment
- file_picker for attachment uploads
- app_links for email verification deep linking
- Biometric / master-password unlock gates
- Rose vault theme (`#F21649`) — no `ColorScheme.fromSeed`

## Setup

### 1. Supabase

1. Create a Supabase project.
2. Enable **Email** auth (disable unused providers for now).
3. In SQL Editor, run the migrations in `supabase/migrations/` in order:
   - `001_initial.sql`
   - `002_folders.sql`
   - `003_attachments.sql`
   - `004_sync.sql`
   - `005_mfa.sql`
   - `006_login_mfa_backup.sql`
4. Confirm the `avatars` and `vault-files` storage buckets exist (created by the migrations above).
5. Enable **Confirm email** and add redirect URL `nucleus://login-callback`.
6. Copy **Project URL** and **publishable key** (formerly called the anon public key).

### 2. App env

```bash
cp .env.example .env
```

Edit `.env`:

```
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_PUBLISHABLE_KEY=your_publishable_key_here
```

Never put the **service role** key in the app.

### 3. Run

```bash
flutter pub get
flutter run
```

### Avatars

Placeholder presets `assets/avatars/1.png` … `60.png` are included. Replace them with your final PNG set (same filenames).

### Loading animation

Brand Lottie: `assets/animations/loading.json`.

## Security model

1. Signup collects only a name and email. The master password is set once, after the user confirms their email via deep link.
2. The master password authenticates with Supabase Auth and, separately, derives a KEK (Argon2id) that wraps a per-user data encryption key (DEK).
3. The wrapped DEK, salt, and KDF parameters live on `profiles`. The DEK itself is generated once and never changes; changing the master password only re-wraps it.
4. Vault payloads are encrypted with the DEK (AES-256-GCM). Ciphertext is bound to its row via additional authenticated data (item id + item type), so it cannot be moved between rows.
5. Attachment files are chunked (plaintext over 5 MB) and encrypted with the same DEK before upload. Filenames, MIME types, and sizes are stored as encrypted metadata, not plaintext columns.
6. Login two-factor authentication (TOTP plus backup codes) is a separate, optional factor. It is wrapped with the KEK rather than the DEK, and only applies at full sign-in — unlocking an existing session never requires it.
7. The built-in authenticator for other sites/services is encrypted with the DEK and always syncs to the cloud, regardless of an individual vault item's local/cloud storage setting.
8. Supabase only ever stores ciphertext, wrapped keys, and opaque storage paths. Plaintext secrets never leave the device.
9. Locking the app clears the in-memory DEK. Biometric unlock reads a device-stored DEK from secure storage after an OS-level biometric check.

## Features

- Email + name signup with email confirmation via deep link; master password set on first vault setup
- Returning login with email + master password, with optional login two-factor authentication (TOTP or backup code)
- Unlock with fingerprint or master password (never requires two-factor)
- Vault items: passwords, bank accounts, ATM/debit/credit cards, notes, and documents (encrypted file attachments)
- Single-level folders with create/rename/delete, folder assignment, and jump-to-folder navigation
- Home screen with global search, type filters, sortable grouped sections, and a skeleton loading state
- Password generator with configurable length and character sets
- Password health checks (weak, reused, old) with a dedicated triage view and a "fix now" flow
- Encrypted file attachments with chunked upload/download and progress tracking
- Local or cloud storage per vault item, backed by a device-local database for local-only items
- Built-in TOTP authenticator for other sites and services, with QR scanning and manual entry
- Screenshot restriction (`FLAG_SECURE`) and Android-specific hardening
- Light / dark / system theme, synced to the backend

## Project layout

```
lib/
  core/           theme, scale, crypto, di, lifecycle, network, errors
  features/       auth, unlock, vault, folders, generator, health, profile, settings, attachments, mfa
  router/
  shared/
supabase/migrations/
  001_initial.sql
  002_folders.sql
  003_attachments.sql
  004_sync.sql
  005_mfa.sql
  006_login_mfa_backup.sql
assets/{icons,avatars,animations}/
```

## Roadmap

Not yet implemented:

- Google OAuth sign-in
- Sharing vault items with other users
- Emergency access / trusted contacts
- OCR-based form filling
- Travel mode (temporarily hide vault subsets)
- Duress unlock (decoy vault)
- Nested folders
- Encrypted export/import of local-only vault data
- iOS and web/desktop support

## Known limitations

- No account recovery path if both the authenticator app and backup codes are lost. The server cannot decrypt anything, so there is no password reset that bypasses the vault.
- Local-only vault items have no cloud backup; losing the device means losing those items.
