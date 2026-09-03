-- Phase 3: encrypted attachments + document item type + vault-files bucket

alter table public.vault_items
  drop constraint if exists vault_items_item_type_check;

alter table public.vault_items
  add constraint vault_items_item_type_check
  check (item_type in (
    'password', 'bank_account', 'atm_card', 'note', 'document'
  ));

create table if not exists public.vault_attachments (
  id uuid primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  vault_item_id uuid not null references public.vault_items (id) on delete cascade,
  storage_root text not null,
  encrypted_metadata text not null,
  metadata_nonce text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists vault_attachments_item_idx
  on public.vault_attachments (vault_item_id);

create index if not exists vault_attachments_user_idx
  on public.vault_attachments (user_id);

drop trigger if exists vault_attachments_set_updated_at on public.vault_attachments;
create trigger vault_attachments_set_updated_at
before update on public.vault_attachments
for each row execute function public.set_updated_at();

alter table public.vault_attachments enable row level security;

drop policy if exists "vault_attachments_select_own" on public.vault_attachments;
create policy "vault_attachments_select_own"
on public.vault_attachments for select
using (auth.uid() = user_id);

drop policy if exists "vault_attachments_insert_own" on public.vault_attachments;
create policy "vault_attachments_insert_own"
on public.vault_attachments for insert
with check (auth.uid() = user_id);

drop policy if exists "vault_attachments_update_own" on public.vault_attachments;
create policy "vault_attachments_update_own"
on public.vault_attachments for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "vault_attachments_delete_own" on public.vault_attachments;
create policy "vault_attachments_delete_own"
on public.vault_attachments for delete
using (auth.uid() = user_id);

-- Private bucket for encrypted attachment chunks (opaque paths).
insert into storage.buckets (id, name, public)
values ('vault-files', 'vault-files', false)
on conflict (id) do nothing;

drop policy if exists "vault_files_select_own" on storage.objects;
create policy "vault_files_select_own"
on storage.objects for select
using (
  bucket_id = 'vault-files'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "vault_files_insert_own" on storage.objects;
create policy "vault_files_insert_own"
on storage.objects for insert
with check (
  bucket_id = 'vault-files'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "vault_files_update_own" on storage.objects;
create policy "vault_files_update_own"
on storage.objects for update
using (
  bucket_id = 'vault-files'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "vault_files_delete_own" on storage.objects;
create policy "vault_files_delete_own"
on storage.objects for delete
using (
  bucket_id = 'vault-files'
  and auth.uid()::text = (storage.foldername(name))[1]
);
