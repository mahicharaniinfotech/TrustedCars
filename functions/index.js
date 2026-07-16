/**
 * TrustedCars — Firebase Cloud Function
 *
 * Sets the `role: authenticated` custom claim on every new Firebase user.
 * This is what tells Supabase (via the Third-Party Auth integration) to
 * treat requests from this user as the `authenticated` Postgres role
 * instead of `anon` — matching how Supabase's own Auth normally works.
 *
 * Deploy with: firebase deploy --only functions
 */

const functions = require("firebase-functions/v1");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");

initializeApp();

exports.addAuthenticatedClaim = functions.auth.user().onCreate(async (user) => {
  await getAuth().setCustomUserClaims(user.uid, { role: "authenticated" });
});
