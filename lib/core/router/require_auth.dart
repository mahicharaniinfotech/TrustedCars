import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/models/account.dart';
import '../../features/auth/providers/auth_providers.dart';

/// Call this before any action that requires being logged in (favoriting,
/// starting a chat, selling, etc). If the current user is a guest, shows a
/// friendly explanation and sends them to sign in instead of silently
/// failing or letting the router bounce them with no context. Returns the
/// logged-in Account if there is one, or null if the guest was redirected.
Account? requireAuth(BuildContext context, WidgetRef ref, {String? message}) {
  final account = ref.read(currentAccountProvider).value;
  if (account != null) return account;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message ?? 'Sign in to continue')),
  );
  context.push('/phone');
  return null;
}
