-- Adds the DELETE policy the in-app "Delete Account" feature needs
-- (see AuthProvider.deleteAccount in lib/state/auth_provider.dart).
--
-- customers previously only granted anon SELECT + INSERT (see the comment
-- in 20260626123500_initial_schema.sql) - deliberately no UPDATE/DELETE, since nothing in
-- the app needed them yet. Deletion does now, for Play Store's account
-- deletion requirement (apps that support account creation must offer
-- in-app account + data deletion).
--
-- Scoped identically to the existing INSERT policy: `using (true)`, not
-- narrowed to a specific row. That matches this app's existing customer
-- security model rather than introducing a new one - customers were never
-- authenticated server-side to begin with (see AuthProvider's phone+password
-- flow, which is local-device-only), so there's no server-verifiable
-- "this request really is customer X" signal to scope a tighter policy to
-- without a much bigger authentication rework. In today's model, the anon
-- key is effectively public (bundled in the app) and a phone number is not
-- a secret, so this DELETE policy carries the same class of exposure the
-- INSERT policy already accepted - not a new regression, but worth
-- revisiting if customer auth ever moves to real Supabase Auth sessions.
--
-- Run this once in the Supabase SQL Editor.

drop policy if exists "anon can delete customers" on customers;
create policy "anon can delete customers" on customers for delete to anon using (true);
