import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../di/onboarding_providers.dart';
import '../presentation/features/help/screens/help_tab_screen.dart';
import '../presentation/features/history/screens/history_tab_screen.dart';
import '../presentation/features/home/screens/home_dashboard_screen.dart';
import '../presentation/features/home/screens/main_navigation_shell.dart';
import '../presentation/features/onboarding/screens/consent_screen.dart';
import '../presentation/features/onboarding/screens/welcome_screen.dart';
import '../presentation/features/settings/screens/settings_tab_screen.dart';

/// Listenable bridge notifying GoRouter whenever persisted onboarding completion changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  void trigger() => notifyListeners();
}

const Set<String> _protectedShellPaths = <String>{
  '/home',
  '/history',
  '/help',
  '/settings',
};

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(
    onboardingControllerProvider.select((s) => (s.isInitialized, s.status.isCompleted)),
    (_, _) => refreshNotifier.trigger(),
  );
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final onboarding = ref.read(onboardingControllerProvider);
      if (!onboarding.isInitialized) return null;

      final loc = state.matchedLocation;
      if (onboarding.status.isCompleted) {
        if (loc == '/welcome' || loc == '/consent') {
          return '/home';
        }
        return null;
      }

      if (_protectedShellPaths.contains(loc)) {
        return onboarding.status.authMode != null ? '/consent' : '/welcome';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/consent',
        builder: (context, state) => const ConsentScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryTabScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/help',
                builder: (context, state) => const HelpTabScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsTabScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
