-- Phase 1.5: single-level vault folders. Names are plaintext metadata.
-- folder_id null on vault_items = Uncategorized. Deleting a folder unassigns items.

create table if not exists public.vault_folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists vault_folders_user_id_idx on public.vault_folders (user_id, sort_order);

alter table public.vault_items
  add column if not exists folder_id uuid references public.vault_folders (id) on delete set null;

create index if not exists vault_items_folder_id_idx on public.vault_items (user_id, folder_id);

drop trigger if exists vault_folders_set_updated_at on public.vault_folders;
create trigger vault_folders_set_updated_at
before update on public.vault_folders
for each row execute function public.set_updated_at();

alter table public.vault_folders enable row level security;

drop policy if exists "folders_select_own" on public.vault_folders;
create policy "folders_select_own"
on public.vault_folders for select
using (auth.uid() = user_id);

drop policy if exists "folders_insert_own" on public.vault_folders;
create policy "folders_insert_own"
on public.vault_folders for insert
with check (auth.uid() = user_id);

drop policy if exists "folders_update_own" on public.vault_folders;
create policy "folders_update_own"
on public.vault_folders for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "folders_delete_own" on public.vault_folders;
create policy "folders_delete_own"
on public.vault_folders for delete
using (auth.uid() = user_id);
