import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/issue_model.dart';
import '../screens/alerts/alerts_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/issues/issue_detail_screen.dart';
import '../screens/issues/issues_screen.dart';
import '../screens/management/manage_issue_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/report/report_screen.dart';
import '../screens/report/report_success_screen.dart';
import '../screens/shell/main_shell_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Riverpod provider delivering the application's GoRouter configuration.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: false,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Tab 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeScreen(),
                ),
              ),
            ],
          ),

          // Tab 1: Issues
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/issues',
                name: 'issues',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: IssuesScreen(),
                ),
              ),
            ],
          ),

          // Tab 2: Report (Centre circular button)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/report',
                name: 'report',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ReportScreen(),
                ),
              ),
            ],
          ),

          // Tab 3: Alerts
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/alerts',
                name: 'alerts',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AlertsScreen(),
                ),
              ),
            ],
          ),

          // Tab 4: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      // Standalone Success Route outside bottom tabs
      GoRoute(
        path: '/report-success',
        name: 'report_success',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ReportSuccessScreen(
            issueId: extra['issueId'] as String? ?? '',
            title: extra['title'] as String? ?? 'Campus Issue',
            area: extra['area'] as String? ?? 'Campus Area',
          );
        },
      ),

      // Issue Detail Route
      GoRoute(
        path: '/issue-detail/:id',
        name: 'issue_detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final issueId = state.pathParameters['id'] ?? '';
          final initialIssue = state.extra as Issue?;
          return IssueDetailScreen(
            issueId: issueId,
            initialIssue: initialIssue,
          );
        },
      ),

      // Management Manage Screen Route
      GoRoute(
        path: '/manage-issue/:id',
        name: 'manage_issue',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final issueId = state.pathParameters['id'] ?? '';
          final initialIssue = state.extra as Issue?;
          return ManageIssueScreen(
            issueId: issueId,
            initialIssue: initialIssue,
          );
        },
      ),
    ],
  );
});
