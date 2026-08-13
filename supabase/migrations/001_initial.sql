-- Nucleus initial schema
-- Apply in Supabase SQL editor (or via CLI). Enable Email auth in dashboard.

create extension if not exists "pgcrypto";

-- Profiles (1:1 with auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '',
  email text not null default '',
  avatar_type text not null default 'preset' check (avatar_type in ('preset', 'custom')),
  avatar_preset_id text,
  avatar_path text,
  theme_preference text not null default 'system'
    check (theme_preference in ('system', 'light', 'dark')),
  encrypted_dek text not null,
  kek_salt text not null,
  kdf_params jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vault_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  item_type text not null
    check (item_type in ('password', 'bank_account', 'atm_card', 'note')),
  encrypted_payload text not null,
  nonce text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists vault_items_user_id_idx on public.vault_items (user_id);
create index if not exists vault_items_type_idx on public.vault_items (user_id, item_type);

-- updated_at trigger
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists vault_items_set_updated_at on public.vault_items;
create trigger vault_items_set_updated_at
before update on public.vault_items
for each row execute function public.set_updated_at();

-- RLS
alter table public.profiles enable row level security;
alter table public.vault_items enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles for select
using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles for insert
with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "vault_select_own" on public.vault_items;
create policy "vault_select_own"
on public.vault_items for select
using (auth.uid() = user_id);

drop policy if exists "vault_insert_own" on public.vault_items;
create policy "vault_insert_own"
on public.vault_items for insert
with check (auth.uid() = user_id);

drop policy if exists "vault_update_own" on public.vault_items;
create policy "vault_update_own"
on public.vault_items for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "vault_delete_own" on public.vault_items;
create policy "vault_delete_own"
on public.vault_items for delete
using (auth.uid() = user_id);

-- Storage bucket for custom avatars
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

drop policy if exists "avatar_read_own" on storage.objects;
create policy "avatar_read_own"
on storage.objects for select
using (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "avatar_insert_own" on storage.objects;
create policy "avatar_insert_own"
on storage.objects for insert
with check (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "avatar_update_own" on storage.objects;
create policy "avatar_update_own"
on storage.objects for update
using (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "avatar_delete_own" on storage.objects;
create policy "avatar_delete_own"
on storage.objects for delete
using (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);
