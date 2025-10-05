import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/features/shop/presentation/shop_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/presentation/welcome_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/signup_page.dart';

/// Thin adapter that turns a Stream into a Listenable so GoRouter can
/// refresh its redirect logic whenever the stream emits (e.g., auth changes).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    // Convert to broadcast and notify listeners on any event.
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    // Always cancel the subscription to avoid memory leaks.
    _sub.cancel();
    super.dispose();
  }
}

/// Global router provider configured with auth-aware redirects.
/// The router rebuilds when [authControllerProvider.notifier].stream emits.
final routerProvider = Provider<GoRouter>((ref) {
  // Use the controller's stream (auth state changes) to trigger router refreshes.
  final refresh = GoRouterRefreshStream(
    ref.watch(authControllerProvider.notifier).stream,
  );

  return GoRouter(
    // First screen shown on cold start.
    initialLocation: '/welcome',

    // Make GoRouter re-run the redirect when the auth stream changes.
    refreshListenable: refresh,

    /// Centralized redirect logic based on authentication status.
    /// - When logged out and trying to access /home -> send to /login
    /// - When logged in and on an auth route -> send to /home
    /// - Otherwise stay on the requested location
    redirect: (context, state) {
      // Read the current AsyncValue<AppUser?> from the controller.
      final auth = ref.read(authControllerProvider);

      // While loading or in error, don't change the current route.
      if (auth.isLoading || auth.hasError) return null;

      // Consider the user logged in if we have a non-null AppUser.
      final loggedIn = auth.asData?.value != null;

      // Current matched route path.
      final loc = state.matchedLocation;

      // Simple check to identify "public" auth routes.
      final isAuthRoute =
          loc.startsWith('/welcome') ||
          loc.startsWith('/login') ||
          loc.startsWith('/signup');

      // Guard the /home route for authenticated users only.
      if (!loggedIn && loc == '/home') return '/login';

      // Prevent navigating back to auth routes once authenticated.
      if (loggedIn && isAuthRoute) return '/home';

      // No redirect.
      return null;
    },

    // Declarative route table.
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomePage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupPage()),
      GoRoute(path: '/home', builder: (_, __) => const ShopPage()),
    ],
  );
});
