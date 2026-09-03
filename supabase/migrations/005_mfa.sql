-- Phase 3: login TOTP on profile + site authenticator entries

alter table public.profiles
  add column if not exists login_totp_enabled boolean not null default false;

alter table public.profiles
  add column if not exists encrypted_login_totp_secret text;

alter table public.profiles
  add column if not exists login_totp_secret_nonce text;

create table if not exists public.mfa_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  encrypted_payload text not null,
  nonce text not null,
  vault_item_id uuid references public.vault_items (id) on delete set null,
  sort_order int not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists mfa_entries_user_idx on public.mfa_entries (user_id);
create index if not exists mfa_entries_vault_item_idx on public.mfa_entries (vault_item_id);

drop trigger if exists mfa_entries_set_updated_at on public.mfa_entries;
create trigger mfa_entries_set_updated_at
before update on public.mfa_entries
for each row execute function public.set_updated_at();

alter table public.mfa_entries enable row level security;

drop policy if exists "mfa_entries_select_own" on public.mfa_entries;
create policy "mfa_entries_select_own"
on public.mfa_entries for select
using (auth.uid() = user_id);

drop policy if exists "mfa_entries_insert_own" on public.mfa_entries;
create policy "mfa_entries_insert_own"
on public.mfa_entries for insert
with check (auth.uid() = user_id);

drop policy if exists "mfa_entries_update_own" on public.mfa_entries;
create policy "mfa_entries_update_own"
on public.mfa_entries for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "mfa_entries_delete_own" on public.mfa_entries;
create policy "mfa_entries_delete_own"
on public.mfa_entries for delete
using (auth.uid() = user_id);
