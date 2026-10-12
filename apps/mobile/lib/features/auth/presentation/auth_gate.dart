import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sprig_mascot.dart';
import '../../../main.dart';
import '../data/auth_providers.dart';
import 'login_screen.dart';

/// Top-level gate widget that routes between authenticated main app and login screen.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    final currentUser = ref.watch(currentUserProvider);

    return authState.when(
      data: (state) {
        if (state.session != null || currentUser != null) {
          return const MainNavigationShell();
        }
        return const LoginScreen();
      },
      loading: () {
        // If we already have a cached or current user, proceed immediately
        if (currentUser != null) {
          return const MainNavigationShell();
        }
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SprigMascot(size: 72, animated: true),
                SizedBox(height: 16),
                CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        );
      },
      error: (_, __) {
        if (currentUser != null) {
          return const MainNavigationShell();
        }
        return const LoginScreen();
      },
    );
  }
}
