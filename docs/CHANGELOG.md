# Changelog

## [2026-08-15] Initial architecture captured

**Summary:** Baseline snapshot of Nucleus as implemented: Flutter + Riverpod (`StateNotifier`) + go_router client that uses Supabase Auth, `profiles`, and `vault_items` with Argon2id/AES-256-GCM zero-knowledge encryption, in-memory DEK sessions, biometric DEK cache, vault CRUD for four item types, profile/avatars, settings (theme, auto-lock, reveal grace, change master password), password generator, and health scoring. No use-case layer, no Riverpod codegen, no offline sync.
**Files:** N/A (baseline)
**Reasoning:** N/A (baseline)
