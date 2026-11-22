import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'router/app_router.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: CampusIssueApp(),
    ),
  );
}

class CampusIssueApp extends ConsumerStatefulWidget {
  const CampusIssueApp({super.key});

  @override
  ConsumerState<CampusIssueApp> createState() => _CampusIssueAppState();
}

class _CampusIssueAppState extends ConsumerState<CampusIssueApp> {
  @override
  void initState() {
    super.initState();
    // Initialize FCM device token registration for the active user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      ref.read(notificationServiceProvider).initializeForUser(user.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Campus Issue App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
