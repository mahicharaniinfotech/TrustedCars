-- ============================================================================
-- TrustedCars — Migration 003: Firebase-compatible user IDs
--
-- Firebase UIDs are ~28-character alphanumeric strings, not UUIDs, and
-- Firebase users never exist in Supabase's own auth.users table. This
-- migration:
--   1. Drops policies that reference the columns being changed (Postgres
--      requires this before altering a column's type)
--   2. Drops the FK from accounts.id -> auth.users.id (no longer valid)
--   3. Changes accounts.id and dealer_profiles.account_id from uuid to text
--   4. Rewrites ownership policies to use auth.jwt()->>'sub' instead of
--      auth.uid() -- auth.uid() internally casts the JWT's sub claim to
--      ::uuid, which throws/returns null for Firebase's non-UUID IDs.
--      auth.jwt()->>'sub' reads the same claim as plain text, which works
--      for both UUID and non-UUID identity providers.
-- ============================================================================

-- ---- 1: drop policies that reference id / account_id ----------------------

drop policy if exists "Users can view own account" on accounts;
drop policy if exists "Users can update own account" on accounts;
drop policy if exists "Users can insert own account" on accounts;
drop policy if exists "Dealers can update own profile" on dealer_profiles;
drop policy if exists "Dealers can insert own profile" on dealer_profiles;

-- ---- 2: drop FKs ------------------------------------------------------

do $$
declare
  fk_name text;
begin
  select tc.constraint_name into fk_name
  from information_schema.table_constraints tc
  join information_schema.key_column_usage kcu
    on tc.constraint_name = kcu.constraint_name
  where tc.table_name = 'accounts'
    and tc.constraint_type = 'FOREIGN KEY'
    and kcu.column_name = 'id';
  if fk_name is not null then
    execute format('alter table accounts drop constraint %I', fk_name);
  end if;
end $$;

do $$
declare
  fk_name text;
begin
  select tc.constraint_name into fk_name
  from information_schema.table_constraints tc
  join information_schema.key_column_usage kcu
    on tc.constraint_name = kcu.constraint_name
  where tc.table_name = 'dealer_profiles'
    and tc.constraint_type = 'FOREIGN KEY'
    and kcu.column_name = 'account_id';
  if fk_name is not null then
    execute format('alter table dealer_profiles drop constraint %I', fk_name);
  end if;
end $$;

-- ---- 3: change column types -------------------------------------------

alter table accounts alter column id type text;
alter table dealer_profiles alter column account_id type text;

alter table dealer_profiles
  add constraint dealer_profiles_account_id_fkey
  foreign key (account_id) references accounts(id) on delete cascade;

-- ---- 4: recreate policies using auth.jwt()->>'sub' ------------------------

create policy "Users can view own account" on accounts
  for select using ((auth.jwt() ->> 'sub') = id);

create policy "Users can update own account" on accounts
  for update using ((auth.jwt() ->> 'sub') = id);

create policy "Users can insert own account" on accounts
  for insert with check ((auth.jwt() ->> 'sub') = id);

create policy "Dealers can update own profile" on dealer_profiles
  for update using ((auth.jwt() ->> 'sub') = account_id);

create policy "Dealers can insert own profile" on dealer_profiles
  for insert with check ((auth.jwt() ->> 'sub') = account_id);

-- ============================================================================
-- End of migration 003
-- ============================================================================
