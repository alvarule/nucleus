---
name: App Login MFA Flow
overview: Implemented guided App Login MFA (re-auth, QR, verify, one-time backup codes). MFA on full sign-in only; unlock unchanged. See docs/ARCHITECTURE.md and CHANGELOG.md.
todos:
  - id: migration-profile-fields
    content: Add migration 006 + UserProfile/repository mapping for encrypted backup payload
    status: completed
  - id: login-mfa-service
    content: LoginMfaService for enrollment, backup hash verify/consume, enable/disable
    status: completed
  - id: auth-login-gates
    content: MFA only on /login → /login-totp; backup codes; no unlock MFA
    status: completed
  - id: setup-wizard-ui
    content: app_login_mfa_pages wizard + modern UI
    status: completed
  - id: settings-manage-disable
    content: Settings tile, manage, disable, regenerate backups
    status: completed
  - id: master-password-rewrap
    content: Re-wrap login MFA blobs on master password change
    status: completed
  - id: docs
    content: ARCHITECTURE.md + CHANGELOG.md
    status: completed
isProject: false
---

# App Login MFA — implemented

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) MFA section and [docs/CHANGELOG.md](docs/CHANGELOG.md).

**Scope:** MFA required only on full sign-in (`/login` → `/login-totp`). Unlock (`/unlock`) uses master password or biometric only.

**Routes:** `/settings/app-login-mfa/setup`, `/settings/app-login-mfa`

**Migration:** `supabase/migrations/006_login_mfa_backup.sql`
