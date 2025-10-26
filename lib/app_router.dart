import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/core/bottom_nav/app_scaffold.dart';
import 'package:flutter_application/core/intro/visual_intro_scene.dart';
import 'package:flutter_application/features/ar/presentation/ar_switch_page.dart';
import 'package:flutter_application/features/ar/presentation/select/ar_coming_soon_page.dart';
import 'package:flutter_application/features/ar/presentation/select/ar_xt_page.dart';
import 'package:flutter_application/features/assistant/presentation/assistant_page.dart';
import 'package:flutter_application/features/favourites/presentation/favourites_page.dart';
import 'package:flutter_application/features/profile/presentation/profile_page.dart';
import 'package:flutter_application/features/shop/presentation/pdf/pdf_viewer_page.dart';
import 'package:flutter_application/features/shop/presentation/product_details_page.dart';
import 'package:flutter_application/features/shop/presentation/shop_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/presentation/welcome_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/signup_page.dart';
import 'features/ar/presentation/landing/ar_landing_page.dart';

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
  final refresh = GoRouterRefreshStream(
    ref.watch(authControllerProvider.notifier).stream,
  );

  return GoRouter(
    initialLocation: '/intro',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading || auth.hasError) return null;

      final loggedIn = auth.asData?.value != null;
      final loc = state.matchedLocation;
      final isAuthRoute =
          loc.startsWith('/welcome') ||
          loc.startsWith('/login') ||
          loc.startsWith('/signup');

      if (!loggedIn && loc == '/home') return '/login';
      if (loggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/intro',    builder: (_, __) => const VisualIntroScene()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomePage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupPage()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppScaffold(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (_, __) =>
                    const NoTransitionPage(child: ShopPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favourites',
                pageBuilder: (_, __) =>
                    const NoTransitionPage(child: FavouritesPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ar',
                pageBuilder: (_, __) =>
                    const NoTransitionPage(child: ARLandingPage()),
                routes: [
                  GoRoute(
                    path: 'xt',
                    pageBuilder: (_, __) =>
                        const NoTransitionPage(child: ARXTPage()),
                  ),
                  GoRoute(
                    path: 'emax',
                    pageBuilder: (_, __) => const NoTransitionPage(
                      child: ComingSoonPage(title: 'Emax AR — Coming soon'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (_, __) =>
                    const NoTransitionPage(child: ProfilePage()),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/product/:id',
        builder: (context, state) =>
            ProductDetailsPage(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/ar-live',
        builder: (ctx, state) {
          final extra = (state.extra as Map?) ?? {};
          return ArSwitchPage(
            title: extra['title'] as String? ?? 'AR Preview',
            glbUrl: extra['glb'] as String?,
            assetGlb: extra['assetGlb'] as String?,
            scale: extra['scale'] as double? ?? 0.2,
          );
        },
      ),
      GoRoute(path: '/assistant', builder: (_, __) => const AssistantPage()),
      GoRoute(
        path: '/pdf-viewer',
        builder: (context, state) {
          final extra = (state.extra ?? {}) as Map;
          return PdfViewerPage(
            title: extra['title'] as String? ?? 'PDF',
            pdfFile: extra['pdfFile'] as String?,
            pdfUrl: extra['pdfUrl'] as String?,
          );
        },
      ),
    ],
  );
});
