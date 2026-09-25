import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth_choice_screen.dart';
import '../screens/main_scaffold.dart';
import '../screens/role_selection_screen.dart';
import '../screens/sign_in_screen.dart';
import '../screens/sign_up_screen.dart';

UserRole _roleFromPath(String? role) {
  return role == 'healthcare' ? UserRole.healthcare : UserRole.parent;
}

Page<void> _fluidPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => _fluidPage(state, const RoleSelectionScreen()),
    ),
    GoRoute(
      path: '/auth/:role',
      pageBuilder: (context, state) => _fluidPage(
        state,
        AuthChoiceScreen(role: _roleFromPath(state.pathParameters['role'])),
      ),
    ),
    GoRoute(
      path: '/sign-in/:role',
      pageBuilder: (context, state) => _fluidPage(
        state,
        SignInScreen(role: _roleFromPath(state.pathParameters['role'])),
      ),
    ),
    GoRoute(
      path: '/sign-up/:role',
      pageBuilder: (context, state) => _fluidPage(
        state,
        SignUpScreen(role: _roleFromPath(state.pathParameters['role'])),
      ),
    ),
    GoRoute(
      path: '/app',
      pageBuilder: (context, state) => _fluidPage(
        state,
        MainScaffold(childName: state.extra as String? ?? 'Aarav'),
      ),
    ),
  ],
);
