-- Phase 3: default sync mode on profile + per-item sync_mode on vault_items

alter table public.profiles
  add column if not exists default_sync_mode text not null default 'cloud'
    check (default_sync_mode in ('cloud', 'local'));

alter table public.vault_items
  add column if not exists sync_mode text not null default 'cloud'
    check (sync_mode in ('cloud', 'local'));
