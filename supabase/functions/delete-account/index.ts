// supabase/functions/delete-account/index.ts
//
// Deletes the calling user's own account. Runs with the service-role key
// (only available server-side) because deleting an auth.users row requires
// admin privileges the client SDK deliberately never has.
//
// Deploy with: supabase functions deploy delete-account
//
// SECURITY: this function trusts the caller's JWT to identify WHO to
// delete (auth.getUser(jwt)) -- it never accepts a user id from the
// request body, so a caller can only ever delete their own account.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
      });
    }
    const jwt = authHeader.replace("Bearer ", "");

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Client scoped to the caller's JWT, used only to identify who's asking.
    const callerClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser(jwt);
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Invalid or expired session" }), {
        status: 401,
      });
    }
    const userId = userData.user.id;

    // Admin client, service-role key -- only usable inside this function.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    // ASSUMPTION: accounts.id references auth.users(id) ON DELETE CASCADE,
    // and vehicles/vehicle_images/listing_features/favorites/messages/
    // conversations/dealer_profiles all reference accounts(id) ON DELETE
    // CASCADE in turn -- so deleting the auth user cascades everything.
    // If any of those FKs are NOT set to cascade, this call will fail with
    // a foreign key violation instead of silently leaving orphaned data,
    // which is the safer failure mode -- but it means those FKs need
    // fixing (or this function needs explicit pre-delete steps added)
    // before deletion actually works end-to-end.
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
    if (deleteError) {
      return new Response(JSON.stringify({ error: deleteError.message }), { status: 500 });
    }

    return new Response(JSON.stringify({ success: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
