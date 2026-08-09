---
name: Vaultify Flutter App
overview: "Vaultify Android-first password manager: Clean Architecture + Riverpod + go_router, Rose vault hand-authored palette (#F21649), login vs fingerprint/password unlock gates, ZK encryption, brand Lottie loader, 60 PNG avatars — you apply Supabase schema."
todos:
  - id: bootstrap
    content: Scaffold Clean Architecture app, explicit Rose vault theme (no fromSeed), go_router, brand Lottie loader, env template
    status: completed
  - id: supabase-sql
    content: "Write supabase/migrations SQL: profiles, vault_items, RLS, avatars bucket policies, updated_at triggers"
    status: completed
  - id: crypto-auth
    content: Auth login (email+password); unlock/reveal gates (fingerprint OR master password); DEK session lock on background
    status: completed
  - id: profile-theme
    content: Profile (name, 60 PNG preset avatars or custom upload), theme preference sync to profiles
    status: completed
  - id: vault-crud
    content: Vault list/detail/forms; masked secrets; fingerprint/password to reveal
    status: completed
  - id: generator-health
    content: Password generator + health checker (strength, reuse summary)
    status: completed
  - id: android-hardening
    content: FLAG_SECURE screenshot block, biometrics, Android-first polish + README
    status: completed
isProject: false
---

# Vaultify — Flutter + Supabase Password Manager

## Decisions locked

- **Frontend architecture:** Clean Architecture (feature-first folders; dependency rule inward)
- **State management:** Riverpod (`flutter_riverpod` + `riverpod_annotation` / codegen) in the presentation layer
- **Platform:** Android first (iOS later; keep code cross-platform-ready)
- **Supabase:** You create the project and apply SQL I provide; share **URL + anon key** only (never service role in the app)
- **Avatars:** 60 preset **PNG** assets you provide; custom gallery upload also supported
- **Loading:** Brand-matched Lottie at `assets/animations/loading.json` (created for Vaultify palette — not `ColorScheme.fromSeed`)
- **Re-auth gate:** Full login = email + master password; app resume / vault open / reveal secrets = master password **or** fingerprint

## Color system (final — hand-authored, not fromSeed)

Direction: **Rose vault** — cool neutral canvases, sharp rose-red actions, calm surfaces. Primary brand `#F21649`. No purple gradients, no cream/terracotta, no neon glow.

### Light

| Token | Hex | Use |
|-------|-----|-----|
| `primary` | `#F21649` | CTA, active nav, FAB, focus |
| `primaryHover` | `#D4143F` | Pressed primary |
| `primarySoft` | `#FFE5EC` | Chips, selected rows, soft fills |
| `onPrimary` | `#FFFFFF` | Text/icons on primary |
| `bg` | `#F7F8FA` | Scaffold |
| `surface` | `#FFFFFF` | Sheets, fields, lists |
| `surfaceMuted` | `#EEF0F3` | Input fill / dividers soft |
| `border` | `#E2E5EB` | Hairlines |
| `textPrimary` | `#14151A` | Titles, body |
| `textSecondary` | `#6B7280` | Hints, meta |
| `textTertiary` | `#9CA3AF` | Masked dots, placeholders |
| `success` | `#0D9F6E` | Health strong |
| `warning` | `#D97706` | Health weak |
| `danger` | `#E11D48` | Destructive (close to brand, distinct enough) |
| `overlay` | `#14151A99` | Unlock scrim |

### Dark

| Token | Hex | Use |
|-------|-----|-----|
| `primary` | `#FF4D73` | Slightly lifted for contrast on dark |
| `primaryHover` | `#F21649` | Pressed |
| `primarySoft` | `#3D1524` | Soft brand container |
| `onPrimary` | `#FFFFFF` | |
| `bg` | `#0F1014` | Scaffold |
| `surface` | `#1A1B22` | Lists, sheets |
| `surfaceMuted` | `#24262F` | Inputs |
| `border` | `#2E303A` | |
| `textPrimary` | `#F4F4F5` | |
| `textSecondary` | `#A1A1AA` | |
| `textTertiary` | `#71717A` | |
| `success` | `#34D399` | |
| `warning` | `#FBBF24` | |
| `danger` | `#FB7185` | |
| `overlay` | `#000000B3` | |

Theme is built with explicit `ColorScheme` + custom `AppColors` extension (and text/button themes). **Do not use `ColorScheme.fromSeed`.**

### Sample UI (design preview)

Previews generated for plan review (see chat / `assets/` previews):

- Login (light) — brand wordmark, email + master password, primary Unlock
- Vault home (dark) — list + bottom nav + rose FAB
- Unlock sheet — fingerprint **or** master password when re-opening app / revealing secrets

### Loading Lottie

At bootstrap, ship `assets/animations/loading.json`: a minimal **concentric pulse / soft vault ring** using `#F21649`, `#FF4D73`, and `#FFE5EC` (light-friendly; still reads on dark surfaces). Shared `VaultLoader` widget; no spinner defaults.

## Architecture overview

```mermaid
flowchart TB
  subgraph presentation [Presentation]
    UI[Pages / Widgets]
    Notifiers[Riverpod Notifiers]
    UI --> Notifiers
  end
  subgraph domain [Domain]
    Entities[Entities]
    RepoIfaces[Repository interfaces]
    UseCases[Use cases]
    UseCases --> RepoIfaces
    UseCases --> Entities
  end
  subgraph data [Data]
    Repos[Repository impls]
    DS[Supabase / secure storage / crypto datasources]
    Models[DTOs / mappers]
    Repos --> DS
    Repos --> Models
  end
  Notifiers --> UseCases
  Repos -.->|implements| RepoIfaces
  DS --> SB[(Supabase)]
```

**Clean Architecture rules (enforced in structure):**

- **Domain** has zero Flutter/Supabase imports — entities, repository contracts, use cases only
- **Data** implements domain repositories; maps DTOs ↔ entities; owns Supabase, secure storage, crypto adapters
- **Presentation** owns UI + Riverpod notifiers/controllers; calls use cases only (not datasources)
- **Core / shared** — theme, responsive `Scale`, errors, DI wiring, routing shell; no feature business rules

**Feature slice (example `vault`):**

```
features/vault/
  domain/     entities, vault_repository.dart, use_cases/
  data/       vault_remote_datasource, vault_repository_impl, mappers
  presentation/  pages, widgets, providers
```

Same pattern for `auth`, `unlock`, `profile`, `generator`, `health`, `settings`.

## Project bootstrap

- Create Flutter app in repo root (`vaultify` / `passmngr`)
- Android min SDK suitable for biometrics + secure flags
- Env via `--dart-define` or `flutter_dotenv` (`.env` gitignored; `.env.example` committed)
- Packages (core): `flutter_riverpod`, `riverpod_annotation`, `go_router`, `supabase_flutter`, `flutter_secure_storage`, `local_auth`, `cryptography` (or PointyCastle), `flutter_svg`, `lottie`, `image_picker`, `freezed` + `json_serializable`, screenshot restriction package (`screen_protector` / equivalent for `FLAG_SECURE`)
- Shared loading widget wraps the provided Lottie JSON; used for auth, vault fetch, profile save, etc.
## Zero-knowledge encryption (v1)

Your approach is sound and supports master-password change. Concrete crypto (simple, strong, not over-engineered):


| Piece        | Choice                                                                                     |
| ------------ | ------------------------------------------------------------------------------------------ |
| KDF          | Argon2id (via `cryptography`) — master password + per-user salt → KEK                      |
| DEK          | 32-byte random key generated at signup                                                     |
| Wrap         | Encrypt DEK with KEK (AES-256-GCM); store `encrypted_dek` + `salt` + KDF params on profile |
| Vault fields | AES-256-GCM with DEK; store ciphertext + nonce (and optional AAD = item id/type)           |
| In-memory    | DEK held only in a Riverpod session notifier after unlock; cleared on lock/logout          |
| Auth         | Same master password used for Supabase Auth sign-in (email + password)                     |


**Signup flow:** Auth signup → generate salt + DEK → wrap DEK → insert `profiles` row → unlock session.  
**Login flow:** Auth sign-in → load profile wrap → derive KEK → unwrap DEK → session ready.  
**Master password change (designed now, UI can be settings later):** unwrap DEK with old password → re-wrap with new → update Auth password + profile wrap in one coordinated flow.

Server stores only ciphertext for vault payloads; RLS ensures users only touch their rows.

## Supabase schema (you apply)

I will deliver SQL under `supabase/migrations/` covering:

`**profiles**`

- `id` UUID PK → `auth.users.id`
- `name` text
- `email` text
- `avatar_type` enum/`text` (`preset` | `custom`)
- `avatar_preset_id` text nullable
- `avatar_path` text nullable (Storage path)
- `theme_preference` text (`system` | `light` | `dark`)
- `encrypted_dek` text/bytea
- `kek_salt` text/bytea
- `kdf_params` jsonb (memory/iterations/parallelism for Argon2)
- `created_at` / `updated_at` timestamptz

`**vault_items**` (single polymorphic table — easier ZK + future types)

- `id` UUID PK
- `user_id` UUID FK → profiles
- `item_type` text/enum: `password` | `bank_account` | `atm_card` | `note`
- `encrypted_payload` text (AES-GCM ciphertext of JSON fields below)
- `nonce` text
- `created_at` / `updated_at` timestamptz  
- Optional non-sensitive index aids only if needed later; v1 encrypts **all** fields including label (list decrypts client-side after unlock)

**Payload field contracts (JSON before encrypt):**

- **password:** `label`*, `url`, `username*`, `password*`, `notes`
- **bank_account:** `label`*, `bank_name*`, `account_type*`, `account_no*`, `ifsc*`, `micr`, `notes`
- **atm_card:** `label`*, `bank_name*`, `name_on_card*`, `card_type*` (credit/debit), `card_no*`, `cvv*`, `expiry_date*`, `atm_pin`, `upi_pin`, `notes`
- **note:** `label`*, `notes*`

**Storage:** private bucket `avatars` — path `{user_id}/...`; RLS: owner read/write.  
**RLS:** all tables `auth.uid() = user_id` / `id`.  
**Triggers:** `updated_at` auto-update.

You will: create project → run migration SQL → create anon key → put URL/anon in `.env`.

## App features — Phase 1 (build now)

### Auth & unlock (session model)

```mermaid
flowchart TD
  cold[Cold start]
  login[Login: email + master password]
  wrap[Unwrap DEK / open vault session]
  vaultUI[Vault UI - secrets masked]
  lock[App locked - session cleared or DEK wiped]
  gate[Gate: fingerprint OR master password]
  reveal[Reveal sensitive field / open item detail]
  cold --> login
  login --> wrap
  wrap --> vaultUI
  vaultUI -->|app background / timeout| lock
  lock --> gate
  gate -->|success| wrap
  vaultUI -->|view password PIN CVV etc| reveal
  reveal -->|if reauth required for reveal| gate
```

- **Signup / first login:** email + master password (Supabase Auth) → derive KEK → unwrap DEK → vault session open
- **Later app opens** (Supabase session may still be valid): do **not** ask for email again; show **Unlock** screen — **fingerprint or master password** only
- **Opening a vault item / viewing masked secrets** (password, PIN, CVV, account numbers, etc.): values stay masked until user passes **fingerprint or master password** (biometric preferred if enrolled; password always available fallback)
- After successful biometric unlock once per “soft session”, optional short grace window for consecutive reveals (UX convenience); leaving app or timeout returns to locked gate
- Device stores biometric-protected unlock material in `flutter_secure_storage` after first successful master-password unlock; never store master password in plaintext

### Profile

- Name, email (from auth), avatar: **60 preset PNGs** in `assets/avatars/` (ids `1`…`60` or filename-based) **or** gallery upload → Storage
- Theme preference synced to `profiles.theme_preference` (`system` | `light` | `dark`)
- Loading states use brand Lottie `assets/animations/loading.json`

### Vault

- List / search (client-side after decrypt) / filter by type
- CRUD for all four item types
- Sensitive fields **always masked by default**; reveal requires fingerprint or master password per gate rules above
- Timestamps shown in device timezone (`DateTime` local conversion from UTC)

### Password generator

- Length, lower/upper/digits/symbols toggles
- Copy to clipboard; “Save as vault item” → password form prefilled

### Password health

- Strength rules (length, charset variety, common-password check against a small local denylist)
- Per-item health badge on password-type vault items; simple summary screen (weak / reused — reuse detection among decrypted passwords in session)

### Hardening / UX polish

- App-wide screenshot restriction (Android `FLAG_SECURE`)
- Explicit **Rose vault** palette from Color system section (no `fromSeed`)
- Responsive: single `Scale` helper (base width e.g. 390) applied to spacing, type, radii — no raw magic numbers in widgets
- Modern SVG icon set (`flutter_svg` + `assets/icons/`); no Material default icons as primary UI icons
- Minimal, convenience-first UI: clear vault home, FAB/add sheet by type, detail with masked secrets

### Navigation (`go_router`)

Typical routes: splash/bootstrap → **login (email + password)** → **unlock (bio | password)** → shell (home, generator, health, settings) → item detail / form → profile. Auth-session present but vault locked → unlock route, not login.

## Folder structure (target)

```
lib/
  main.dart
  app.dart
  router/
  core/                    # theme, scale, errors, screenshot, DI — no feature logic
  features/
    auth/
      domain/
      data/
      presentation/
    unlock/
      domain/
      data/
      presentation/
    vault/
      domain/
      data/
      presentation/
    generator/
      domain/
      data/                 # if any persistence; else domain + presentation only
      presentation/
    health/
      domain/
      presentation/
    profile/
      domain/
      data/
      presentation/
    settings/
      domain/
      data/
      presentation/
  shared/                  # cross-feature widgets (Lottie loader, masked field, etc.)
assets/
  icons/                   # SVG UI icons
  avatars/                 # 60 preset PNGs (you supply)
  animations/              # loading.json — brand Lottie (shipped with app)
supabase/migrations/
.env.example
```

Crypto lives behind a domain port (e.g. `VaultCrypto` / `KeyWrapService`) with the implementation in `data` or `core/crypto` injected via Riverpod — presentation never touches raw keys beyond session state owned by an unlock use-case/notifier.
## Phase 2 — planned later (schema/app hooks only where cheap)


| Feature                | Keep in mind now                                                                                                          |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Local / cloud / both   | Abstract `VaultRepository`; later add local DB (Drift/Isar) + sync flag column                                            |
| Share by email         | Future `shares` table + re-encryption to recipient DEK (needs public key or wrap ceremony)                                |
| Open site + auto-login | Android intents / custom tabs; never expose password in UI                                                                |
| Secure documents       | Storage bucket + encrypted blobs; new `item_type`                                                                         |
| OCR                    | Camera + ML kit pipeline into forms                                                                                       |
| Emergency access       | `emergency_contacts`, `access_requests`, wait period, owner deny — design like Dashlane; crypto needs trustee wrap of DEK |
| Hide-my-email          | External email relay provider later                                                                                       |
| Travel mode            | Temporary hide/exclude vault subsets                                                                                      |
| Duress unlock          | Secondary password → decoy vault or wipe flag (careful product/legal design)                                              |


Phase 1 code stays modular so these plug in without rewriting crypto core.

## Supabase collaboration checklist

1. I write `supabase/migrations/001_initial.sql` (tables, enums, RLS, storage policies, triggers)
2. You create Supabase project and run the SQL
3. You enable Email auth; disable unused providers for now
4. You create `avatars` bucket per migration notes
5. You send **Project URL** + **anon public key** for `.env`
6. Drop **60 preset avatar PNGs** into `assets/avatars/` when ready (placeholders until then). Loading Lottie is created to match the Rose vault palette during bootstrap.

## Implementation order

1. Flutter project + Clean Architecture folders + deps + explicit theme tokens + scale/router + brand Lottie loader
2. Supabase migration SQL + env wiring
3. Domain ports + crypto/auth/unlock use cases (login vs unlock gates) + data impls + presentation
4. Profile + theme preference + 60 PNG presets / custom upload
5. Vault CRUD + masked secrets + fingerprint/password reveal gate
6. Generator + health
7. Screenshot guard + Android polish
8. README: run instructions, schema apply steps, asset drop-in notes, security notes

## Out of scope for Phase 1

- iOS shipping, web/desktop
- Sharing, emergency access, OCR, documents, travel/duress, hide-my-email
- Offline-first sync (interfaces only if useful)
- Password change UI can ship as thin settings action once wrap/rewrap works

