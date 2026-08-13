# Nucleus

Zero-knowledge password manager for Android (Flutter + Supabase).

## Stack

- Flutter + Riverpod + go_router
- Clean Architecture (`features/*/domain|data|presentation`)
- Supabase Auth + Postgres + Storage
- Argon2id + AES-256-GCM client-side encryption
- Biometric / master-password unlock gates
- Rose vault theme (`#F21649`) — no `ColorScheme.fromSeed`

## Setup

### 1. Supabase

1. Create a Supabase project.
2. Enable **Email** auth (disable unused providers for now).
3. In SQL Editor, run [`supabase/migrations/001_initial.sql`](supabase/migrations/001_initial.sql).
4. Confirm the `avatars` storage bucket exists (created by the migration).
5. Copy **Project URL** and **publishable key** (formerly called the anon public key).

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

1. Signup generates a random DEK + salt.
2. DEK is wrapped with a KEK derived from the master password via Argon2id.
3. Wrapped DEK + salt + KDF params live on `profiles`.
4. Vault payloads are AES-256-GCM encrypted with the DEK before upload.
5. Server never sees plaintext secrets.
6. App lock clears the in-memory DEK; biometric unlock reads a device-stored DEK from secure storage after OS biometric check.

## Features (Phase 1)

- Email + master password accounts
- Profile (name, email, 60 presets / custom photo, theme preference)
- Vault types: password, bank account, ATM card, note
- Unlock / reveal with fingerprint **or** master password
- Password generator + health checker
- Screenshot restriction (`FLAG_SECURE`)
- Light / dark / system theme synced to backend

## Project layout

```
lib/
  core/           theme, scale, crypto, di, lifecycle
  features/       auth, unlock, vault, generator, health, profile, settings
  router/
  shared/
supabase/migrations/
assets/{icons,avatars,animations}/
```
