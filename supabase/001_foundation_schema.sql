-- ============================================================================
-- KDMC — Migration 001: Foundation Schema
-- Accounts, Roles, Verification, and India Location Master Tables
-- Run this in Supabase SQL Editor (or via `supabase db push`)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Extensions
-- ----------------------------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists postgis; -- for lat/long distance queries later

-- ----------------------------------------------------------------------------
-- 1. Enums
-- ----------------------------------------------------------------------------
create type account_type as enum ('individual', 'dealer', 'admin');
create type verification_status as enum ('unverified', 'pending', 'verified', 'rejected');

-- ----------------------------------------------------------------------------
-- 2. Location master tables (India geography)
--    Buyers/sellers pick from these via dropdowns — never free text.
-- ----------------------------------------------------------------------------
create table states (
  id            bigint generated always as identity primary key,
  name          text not null unique,
  code          text unique          -- e.g. 'TG', 'KA'
);

create table districts (
  id            bigint generated always as identity primary key,
  state_id      bigint not null references states(id) on delete cascade,
  name          text not null,
  unique (state_id, name)
);

create table cities (
  id            bigint generated always as identity primary key,
  district_id   bigint not null references districts(id) on delete cascade,
  name          text not null,
  unique (district_id, name)
);

create table areas (
  id            bigint generated always as identity primary key,
  city_id       bigint not null references cities(id) on delete cascade,
  name          text not null,
  unique (city_id, name)
);

create index idx_districts_state on districts(state_id);
create index idx_cities_district on cities(district_id);
create index idx_areas_city on areas(city_id);

-- ----------------------------------------------------------------------------
-- 3. Accounts
--    One row per authenticated user, extending Supabase's built-in auth.users.
--    A vehicle later belongs to an Account, not directly to a "seller".
-- ----------------------------------------------------------------------------
create table accounts (
  id                    uuid primary key references auth.users(id) on delete cascade,
  account_type          account_type not null default 'individual',
  full_name             text,
  phone                 text unique,
  email                 text,
  avatar_url            text,

  -- location (nullable until the user sets it)
  state_id              bigint references states(id),
  district_id           bigint references districts(id),
  city_id               bigint references cities(id),
  area_id               bigint references areas(id),

  -- trust / verification — result only, never raw documents
  verification_status   verification_status not null default 'unverified',
  verified_at           timestamptz,
  verification_ref      text,        -- opaque reference id from KYC provider, not the Aadhaar number itself

  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index idx_accounts_type on accounts(account_type);
create index idx_accounts_verification on accounts(verification_status);

-- ----------------------------------------------------------------------------
-- 4. Dealer profile (1:1 extension of accounts where account_type = 'dealer')
-- ----------------------------------------------------------------------------
create table dealer_profiles (
  account_id            uuid primary key references accounts(id) on delete cascade,
  business_name         text not null,
  gst_number            text,
  business_address      text,
  latitude              double precision,
  longitude             double precision,
  business_hours        jsonb,       -- e.g. {"mon": "9:00-19:00", ...}
  years_in_business     int,
  rating                numeric(2,1) default 0.0,
  vehicles_sold_count   int not null default 0,
  subscription_tier     text default 'starter', -- starter | professional | enterprise
  subscription_active   boolean not null default false,
  created_at            timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 5. updated_at trigger helper (reused by every future table)
-- ----------------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_accounts_updated_at
before update on accounts
for each row execute function set_updated_at();

-- ----------------------------------------------------------------------------
-- 6. Auto-create an account row whenever someone signs up via Supabase Auth
-- ----------------------------------------------------------------------------
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.accounts (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', ''));
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function handle_new_user();

-- ----------------------------------------------------------------------------
-- 7. Row Level Security
-- ----------------------------------------------------------------------------
alter table accounts enable row level security;
alter table dealer_profiles enable row level security;
alter table states enable row level security;
alter table districts enable row level security;
alter table cities enable row level security;
alter table areas enable row level security;

-- Location master tables: readable by everyone (guests included), writable only by admins
create policy "Locations are publicly readable" on states for select using (true);
create policy "Districts are publicly readable" on districts for select using (true);
create policy "Cities are publicly readable" on cities for select using (true);
create policy "Areas are publicly readable" on areas for select using (true);

-- Accounts: a user can read/update only their own account row
create policy "Users can view own account" on accounts
  for select using (auth.uid() = id);

create policy "Users can update own account" on accounts
  for update using (auth.uid() = id);

-- Dealer profiles: publicly readable (this is the public storefront),
-- but only the owning dealer can insert/update their own profile
create policy "Dealer profiles are publicly readable" on dealer_profiles
  for select using (true);

create policy "Dealers can update own profile" on dealer_profiles
  for update using (auth.uid() = account_id);

create policy "Dealers can insert own profile" on dealer_profiles
  for insert with check (auth.uid() = account_id);

-- ----------------------------------------------------------------------------
-- 8. Seed a handful of states/districts/cities to develop against
--    (Full official dataset gets loaded separately — see seed script note below)
-- ----------------------------------------------------------------------------
insert into states (name, code) values
  ('Telangana', 'TG'),
  ('Andhra Pradesh', 'AP'),
  ('Karnataka', 'KA')
on conflict do nothing;

insert into districts (state_id, name)
  select id, 'Hyderabad' from states where code = 'TG'
  union all
  select id, 'Visakhapatnam' from states where code = 'AP'
  union all
  select id, 'Bengaluru Urban' from states where code = 'KA'
on conflict do nothing;

insert into cities (district_id, name)
  select id, 'Hyderabad' from districts where name = 'Hyderabad'
  union all
  select id, 'Visakhapatnam' from districts where name = 'Visakhapatnam'
  union all
  select id, 'Bengaluru' from districts where name = 'Bengaluru Urban'
on conflict do nothing;

insert into areas (city_id, name)
  select id, x.area from cities, (values ('Gachibowli'),('Madhapur'),('Kondapur'),('Kukatpally')) as x(area)
  where cities.name = 'Hyderabad'
on conflict do nothing;

-- ============================================================================
-- End of migration 001
-- Next migration (002) will add: vehicles, vehicle_images, brands/models master data
-- ============================================================================
