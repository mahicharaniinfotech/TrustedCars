import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the in-app animated splash has finished its entrance
/// animation. The router holds on '/splash' until this flips true, then
/// falls through to the normal auth-based redirect logic.
class SplashCompleteNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() => state = true;
}

final splashCompleteProvider = NotifierProvider<SplashCompleteNotifier, bool>(SplashCompleteNotifier.new);
