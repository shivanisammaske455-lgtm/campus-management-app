import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/issue_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/issue_card.dart';
import '../management/management_dashboard_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    // Role-based UI: If role is "management", show the Management Dashboard instead of standard Home
    if (currentUser.isManagement) {
      return const ManagementDashboardScreen();
    }

    final greeting = ref.watch(timeGreetingProvider);
    final myIssuesAsync = ref.watch(myIssuesStreamProvider(currentUser.uid));

    return Scaffold(
      backgroundColor: AppTheme.offWhiteBg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.school_rounded,
                  size: 20,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, ${currentUser.firstName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  currentUser.email,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Alerts',
            onPressed: () => context.go('/alerts'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myIssuesStreamProvider(currentUser.uid));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------------------------------------------------
              // 1. Large "Report a problem" Button
              // ---------------------------------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryGreen, AppTheme.primaryGreenDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.go('/report'),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 18.0,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_a_photo_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Report a Problem',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Garden, plumbing, electrics, or furniture',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ---------------------------------------------------------
              // 2. Three Stat Tiles: My Reports, Resolved, Pending
              // ---------------------------------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: myIssuesAsync.when(
                  data: (issues) {
                    final total = issues.length;
                    final resolved = issues
                        .where((i) => i.status == IssueStatus.resolved)
                        .length;
                    final pending = issues
                        .where((i) => i.status != IssueStatus.resolved)
                        .length;

                    return Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            title: 'My Reports',
                            count: total,
                            icon: Icons.assignment_outlined,
                            accentColor: AppTheme.primaryGreen,
                            bgColor: AppTheme.surfaceWhite,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            title: 'Resolved',
                            count: resolved,
                            icon: Icons.check_circle_outline_rounded,
                            accentColor: AppStatusColors.resolvedText,
                            bgColor: AppStatusColors.resolvedBg,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            title: 'Pending',
                            count: pending,
                            icon: Icons.hourglass_top_rounded,
                            accentColor: AppStatusColors.inProgressText,
                            bgColor: AppStatusColors.inProgressBg,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Row(
                    children: [
                      Expanded(child: _StatLoadingTile()),
                      SizedBox(width: 10),
                      Expanded(child: _StatLoadingTile()),
                      SizedBox(width: 10),
                      Expanded(child: _StatLoadingTile()),
                    ],
                  ),
                  error: (error, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Stats temporarily unavailable: $error',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ---------------------------------------------------------
              // 3. 3 Most Recent of "My Reports"
              // ---------------------------------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My Recent Reports',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/issues'),
                      child: const Text('View all'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              myIssuesAsync.when(
                data: (issues) {
                  if (issues.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.assignment_turned_in_outlined,
                                  color: AppTheme.primaryGreen,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No issues reported yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Notice something broken or leaking on campus? Tap the button above to report it!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Take only the 3 most recent
                  final recentIssues = issues.take(3).toList();

                  return Column(
                    children: recentIssues.map((issue) {
                      return IssueCard(
                        issue: issue,
                        currentUserId: currentUser.uid,
                        onTap: () {
                          context.push(
                            '/issue-detail/${issue.id}',
                            extra: issue,
                          );
                        },
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                  ),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error loading reports: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;

  const _StatTile({
    required this.title,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              Icon(icon, size: 20, color: accentColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColor.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatLoadingTile extends StatelessWidget {
  const _StatLoadingTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
