-- Tabel kos
create table if not exists public.kos (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null default auth.uid()
             references auth.users(id) on delete cascade,
  name       text not null,
  address    text,
  price      integer,
  created_at timestamptz not null default now()
);

-- Aktifkan RLS
alter table public.kos enable row level security;

-- 1. SELECT: semua user yang sudah login boleh membaca
create policy "kos_select_authenticated"
  on public.kos for select to authenticated
  using (true);

-- 2. INSERT: owner_id harus sama dengan user yang login,
--    dan role harus owner / admin
create policy "kos_insert_owner"
  on public.kos for insert to authenticated
  with check (
    auth.uid() = owner_id
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('owner', 'admin')
    )
  );

-- 3. UPDATE: hanya pemilik data
create policy "kos_update_own"
  on public.kos for update to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- 4. DELETE: hanya pemilik data
create policy "kos_delete_own"
  on public.kos for delete to authenticated
  using (auth.uid() = owner_id);

-- 5. Policy untuk Admin
create or replace function public.is_admin()
returns boolean
language sql stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create policy "kos_admin_all"
  on public.kos for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());
