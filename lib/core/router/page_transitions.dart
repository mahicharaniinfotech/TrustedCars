import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A shared fade transition for every route -- replaces GoRouter's default
/// platform page-flip with a softer cross-fade, so navigating through the
/// app feels considered rather than abrupt. Used via pageBuilder on every
/// GoRoute instead of the plain builder: parameter.
CustomTransitionPage<void> fadeTransitionPage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}
