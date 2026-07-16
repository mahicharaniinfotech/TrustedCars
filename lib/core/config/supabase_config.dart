/// TrustedCars — Supabase Configuration
///
/// Supabase no longer issues its own session for our users — Firebase does
/// (see AuthRepository). This client trusts Firebase's ID token instead,
/// via the accessToken callback below, per Supabase's Third-Party Auth
/// integration (already connected in the dashboard: Authentication ->
/// Third-Party Auth -> Firebase, project trustedcars-20e2f).
///
/// The anon key below is still required (it identifies which Supabase
/// project is being called), but it's no longer what authorizes requests —
/// the Firebase ID token is. Row Level Security policies (see
/// 003_firebase_compatible_ids.sql) key off auth.jwt()->>'sub', which reads
/// straight from that Firebase token.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract final class SupabaseConfig {
  static const String projectUrl = 'https://wegddvbxtiidnityycyy.supabase.co';

  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndlZ2RkdmJ4dGlpZG5pdHl5Y3l5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxODYwOTksImV4cCI6MjA5OTc2MjA5OX0.L4ssSGi42V5j9zq4-Jf19cyZsGued2t3__oGIcRgb6w';

  static Future<void> init() async {
    await Supabase.initialize(
      url: projectUrl,
      anonKey: anonKey,
      accessToken: () async {
        return FirebaseAuth.instance.currentUser?.getIdToken();
      },
    );
  }
}

/// Shorthand accessor used throughout the app, e.g.:
///   supabase.from('accounts').select()
final supabase = Supabase.instance.client;
