-- Login MFA backup codes (KEK-wrapped hash payload on profile)

alter table public.profiles
  add column if not exists encrypted_login_backup_payload text;

alter table public.profiles
  add column if not exists login_backup_payload_nonce text;
