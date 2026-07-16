-- ============================================================================
-- TrustedCars — Migration 002: Firebase Third-Party Auth support
-- Run this in Supabase SQL Editor after connecting the Firebase integration
-- (Authentication -> Third-Party Auth) in the dashboard.
-- ============================================================================

-- Firebase-authenticated users never pass through Supabase's own auth.users
-- table, so the on_auth_user_created trigger from migration 001 never fires
-- for them. The app now creates the accounts row itself on first login
-- (see AccountRepository.ensureAccountExists) -- this policy allows that.
create policy "Users can insert own account" on accounts
  for insert with check (auth.uid() = id);

-- ============================================================================
-- Optional but recommended before a real production launch: a restrictive
-- policy that rejects JWTs from any Firebase project other than yours.
-- Firebase's JWT signing keys are shared globally across all Firebase
-- projects, so without this, in theory a JWT from an unrelated Firebase
-- project could pass signature verification. Supabase's hosted platform
-- already blocks this at the gateway level before it reaches your database,
-- so this is defense-in-depth, not strictly required to function.
--
-- Uncomment and fill in your actual IDs to enable it:
--
-- create policy "Restrict to this project's auth only" on accounts
--   as restrictive
--   to authenticated
--   using (
--     (auth.jwt()->>'iss' = 'https://<your-supabase-project-ref>.supabase.co/auth/v1')
--     or (
--       auth.jwt()->>'iss' = 'https://securetoken.google.com/<your-firebase-project-id>'
--       and auth.jwt()->>'aud' = '<your-firebase-project-id>'
--     )
--   );
-- ============================================================================
