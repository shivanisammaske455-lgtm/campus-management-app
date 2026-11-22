import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/issue_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/status_chip.dart';

/// Management Dashboard: Displayed as the primary Home view for users with role == 'management'.
class ManagementDashboardScreen extends ConsumerWidget {
  const ManagementDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final allIssuesAsync = ref.watch(allIssuesStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.offWhiteBg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.admin_panel_settings_rounded,
                      size: 18, color: AppTheme.primaryGreen),
                  SizedBox(width: 6),
                  Text(
                    'Management',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Campus Dashboard',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Issues',
            onPressed: () => ref.invalidate(allIssuesStreamProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(allIssuesStreamProvider),
        child: allIssuesAsync.when(
          data: (issues) {
            // Compute counts
            final newCount =
                issues.where((i) => i.status == IssueStatus.reported).length;
            final inProgressCount =
                issues.where((i) => i.status == IssueStatus.inProgress).length;
            final resolvedCount =
                issues.where((i) => i.status == IssueStatus.resolved).length;
            final urgentCount = issues
                .where((i) =>
                    i.priority == IssuePriority.urgent &&
                    i.status != IssueStatus.resolved)
                .length;

            // Sort newest issues with urgent unresolved ones first
            final sortedIssues = [...issues]..sort((a, b) {
                final aUrgent = a.priority == IssuePriority.urgent &&
                    a.status != IssueStatus.resolved;
                final bUrgent = b.priority == IssuePriority.urgent &&
                    b.status != IssueStatus.resolved;

                if (aUrgent && !bUrgent) return -1;
                if (!aUrgent && bUrgent) return 1;

                return b.createdAt.compareTo(a.createdAt);
              });

            return CustomScrollView(
              slivers: [
                // ---------------------------------------------------
                // 1. Dashboard Header & 4 Stat Cards
                // (New, In progress, Resolved, Urgent)
                // ---------------------------------------------------
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operations Overview',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ManagementStatCard(
                                title: 'New',
                                count: newCount,
                                icon: Icons.fiber_new_rounded,
                                accentColor: AppStatusColors.reportedText,
                                bgColor: AppStatusColors.reportedBg,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ManagementStatCard(
                                title: 'In Progress',
                                count: inProgressCount,
                                icon: Icons.pending_actions_rounded,
                                accentColor: AppStatusColors.inProgressText,
                                bgColor: AppStatusColors.inProgressBg,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _ManagementStatCard(
                                title: 'Resolved',
                                count: resolvedCount,
                                icon: Icons.task_alt_rounded,
                                accentColor: AppStatusColors.resolvedText,
                                bgColor: AppStatusColors.resolvedBg,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ManagementStatCard(
                                title: 'Urgent',
                                count: urgentCount,
                                icon: Icons.warning_amber_rounded,
                                accentColor: const Color(0xFFDC2626),
                                bgColor: const Color(0xFFFEE2E2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Action Queue (Urgent First)',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              '${sortedIssues.length} total',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ---------------------------------------------------
                // 2. Issue Queue (Urgent First, Then Newest)
                // ---------------------------------------------------
                if (sortedIssues.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('No campus issues reported yet.'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final issue = sortedIssues[index];
                        final isUrgent =
                            issue.priority == IssuePriority.urgent &&
                                issue.status != IssueStatus.resolved;

                        return _ManagementIssueCard(
                          issue: issue,
                          isUrgent: isUrgent,
                          onTap: () {
                            context.push(
                              '/manage-issue/${issue.id}',
                              extra: issue,
                            );
                          },
                        );
                      },
                      childCount: sortedIssues.length,
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Could not load dashboard: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagementStatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;

  const _ManagementStatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accentColor.withOpacity(0.9),
                ),
              ),
            ],
          ),
          Icon(icon, size: 26, color: accentColor),
        ],
      ),
    );
  }
}

class _ManagementIssueCard extends StatelessWidget {
  final Issue issue;
  final bool isUrgent;
  final VoidCallback onTap;

  const _ManagementIssueCard({
    required this.issue,
    required this.isUrgent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUrgent ? const Color(0xFFDC2626) : AppTheme.borderLight,
          width: isUrgent ? 1.8 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isUrgent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: const [
                      Icon(Icons.priority_high_rounded,
                          size: 16, color: Color(0xFFDC2626)),
                      SizedBox(width: 4),
                      Text(
                        'URGENT ATTENTION REQUIRED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 68,
                      height: 68,
                      color: AppTheme.offWhiteBg,
                      child: issue.photoUrls.isNotEmpty
                          ? Image.network(
                              issue.photoUrls.first,
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image, size: 28),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.build_outlined,
                                  color: AppTheme.primaryGreen),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.title.isNotEmpty ? issue.title : 'Campus Issue',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              issue.area,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('•',
                                style: TextStyle(color: AppTheme.textSecondary)),
                            const SizedBox(width: 8),
                            Text(
                              issue.category.label,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reported by: ${issue.reporterName.isNotEmpty ? issue.reporterName : "Campus Member"}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusChip(status: issue.status),
                  if (issue.assignedTo.isNotEmpty)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.engineering_outlined,
                              size: 14, color: AppTheme.primaryGreen),
                          const SizedBox(width: 4),
                          Text(
                            issue.assignedTo,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Text(
                      'Unassigned',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStatusColors.reportedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
