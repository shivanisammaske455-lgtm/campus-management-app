import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/issue_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/status_chip.dart';

class IssueDetailScreen extends ConsumerStatefulWidget {
  final String issueId;
  final Issue? initialIssue;

  const IssueDetailScreen({
    super.key,
    required this.issueId,
    this.initialIssue,
  });

  @override
  ConsumerState<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends ConsumerState<IssueDetailScreen> {
  int _currentCarouselIndex = 0;
  bool _isProcessingAction = false;

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleReopenIssue(Issue issue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reopen Issue?'),
        content: const Text(
          'If this issue is still unresolved, you can send it back to management. The status will return to "Reported".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStatusColors.reportedText,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reopen Issue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessingAction = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.reopenIssue(issue.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue reopened and sent back to management.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not reopen issue: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _handleConfirmFixed(Issue issue) async {
    setState(() => _isProcessingAction = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.confirmFixed(issue.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! You have confirmed this issue is resolved.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppStatusColors.resolvedText,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not confirm resolution: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Live Firestore stream for real-time updates
    final issueStreamAsync = ref.watch(singleIssueStreamProvider(widget.issueId));
    final issue = issueStreamAsync.value ?? widget.initialIssue;

    if (issue == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Issue Details')),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    final isResolved = issue.status == IssueStatus.resolved;

    return Scaffold(
      backgroundColor: AppTheme.offWhiteBg,
      appBar: AppBar(
        title: const Text('Issue Details'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(child: StatusChip(status: issue.status)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------------
            // 1. Photo Carousel with Indicators
            // -------------------------------------------------------
            if (issue.photoUrls.isNotEmpty)
              Column(
                children: [
                  SizedBox(
                    height: 250,
                    child: PageView.builder(
                      itemCount: issue.photoUrls.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentCarouselIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final photoUrl = issue.photoUrls[index];
                        return Container(
                          color: Colors.black12,
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                size: 48,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryGreen,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  if (issue.photoUrls.length > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: issue.photoUrls.asMap().entries.map((entry) {
                          final isSelected = _currentCarouselIndex == entry.key;
                          return Container(
                            width: isSelected ? 18 : 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.borderLight,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              )
            else
              Container(
                height: 140,
                width: double.infinity,
                color: AppTheme.primaryGreen.withOpacity(0.08),
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),

            // -------------------------------------------------------
            // 2. Title & Status
            // -------------------------------------------------------
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.title.isNotEmpty ? issue.title : 'Campus Issue',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // AI Triage Badge
                  if (issue.aiTriage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 18, color: Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Gemini AI Triage',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF166534),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '"${issue.aiTriage!['oneLineSummary'] ?? ''}"',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                                if (issue.aiTriage!['suggestedDepartment'] != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Recommended: ${issue.aiTriage!['suggestedDepartment']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // -------------------------------------------------------
                  // 3. Description
                  // -------------------------------------------------------
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            issue.description.isNotEmpty
                                ? issue.description
                                : 'No description provided.',
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // -------------------------------------------------------
                  // 4. Details List (Location, Category, Priority, Time, Reporter)
                  // -------------------------------------------------------
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.place_outlined,
                            label: 'Campus Area',
                            value: issue.area,
                          ),
                          const Divider(height: 20),
                          _DetailRow(
                            icon: Icons.category_outlined,
                            label: 'Category',
                            value: issue.category.label,
                          ),
                          const Divider(height: 20),
                          _DetailRow(
                            icon: Icons.flag_outlined,
                            label: 'Priority',
                            value: issue.priority.label,
                          ),
                          const Divider(height: 20),
                          _DetailRow(
                            icon: Icons.access_time_rounded,
                            label: 'Reported At',
                            value: _formatDateTime(issue.createdAt),
                          ),
                          const Divider(height: 20),
                          _DetailRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Reported By',
                            value: issue.reporterName.isNotEmpty
                                ? issue.reporterName
                                : 'Campus Member',
                          ),
                          if (issue.assignedTo.isNotEmpty) ...[
                            const Divider(height: 20),
                            _DetailRow(
                              icon: Icons.engineering_outlined,
                              label: 'Assigned Team',
                              value: issue.assignedTo,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // -------------------------------------------------------
                  // 5. Vertical Progress Timeline
                  // (Reported -> Sent to management -> In progress -> Resolved)
                  // -------------------------------------------------------
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Resolution Timeline',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _TimelineStep(
                            title: 'Reported',
                            subtitle:
                                'Issue submitted with photo and campus GPS',
                            isCompleted: true,
                            isCurrent: issue.status == IssueStatus.reported,
                            isFirst: true,
                          ),
                          _TimelineStep(
                            title: 'Sent to management',
                            subtitle:
                                'Notification delivered to college facilities team',
                            isCompleted: true,
                            isCurrent: false,
                          ),
                          _TimelineStep(
                            title: 'In progress',
                            subtitle: issue.status == IssueStatus.inProgress
                                ? 'Maintenance team is actively resolving this'
                                : (isResolved
                                    ? 'Work completed by campus team'
                                    : 'Awaiting team assignment'),
                            isCompleted: issue.status == IssueStatus.inProgress ||
                                isResolved,
                            isCurrent: issue.status == IssueStatus.inProgress,
                          ),
                          _TimelineStep(
                            title: 'Resolved',
                            subtitle: isResolved
                                ? 'Resolved on ${_formatDateTime(issue.resolvedAt ?? issue.updatedAt)}'
                                : 'Pending resolution and verification photo',
                            isCompleted: isResolved,
                            isCurrent: isResolved,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // -------------------------------------------------------
                  // 6. When Resolved: Before and After Photo Comparison & Action Buttons
                  // -------------------------------------------------------
                  if (isResolved) ...[
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.compare_rounded,
                                  color: AppStatusColors.resolvedText,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Before & After Comparison',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                // Before Photo
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppStatusColors.reportedBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'BEFORE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppStatusColors.reportedText,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          height: 130,
                                          width: double.infinity,
                                          color: Colors.black12,
                                          child: issue.photoUrls.isNotEmpty
                                              ? Image.network(
                                                  issue.photoUrls.first,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Center(
                                                    child: Icon(Icons.broken_image),
                                                  ),
                                                )
                                              : const Center(
                                                  child: Icon(Icons.photo),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // After Photo
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppStatusColors.resolvedBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'AFTER',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppStatusColors.resolvedText,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          height: 130,
                                          width: double.infinity,
                                          color: Colors.black12,
                                          child: (issue.afterPhotoUrl != null &&
                                                  issue.afterPhotoUrl!.isNotEmpty)
                                              ? Image.network(
                                                  issue.afterPhotoUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Center(
                                                    child: Icon(Icons.broken_image),
                                                  ),
                                                )
                                              : const Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.task_alt,
                                                        color: AppStatusColors
                                                            .resolvedText,
                                                      ),
                                                      SizedBox(height: 4),
                                                      Text(
                                                        'Fixed by team',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: AppTheme
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons: "Confirm fixed" and "Not fixed, reopen"
                    Row(
                      children: [
                        // Button 1: "Not fixed, reopen"
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _isProcessingAction
                                  ? null
                                  : () => _handleReopenIssue(issue),
                              icon: const Icon(
                                Icons.replay_rounded,
                                color: AppStatusColors.reportedText,
                              ),
                              label: const Text(
                                'Not fixed, reopen',
                                style: TextStyle(
                                  color: AppStatusColors.reportedText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppStatusColors.reportedBorder,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Button 2: "Confirm fixed"
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isProcessingAction
                                  ? null
                                  : () => _handleConfirmFixed(issue),
                              icon: const Icon(Icons.check_circle_rounded),
                              label: const Text(
                                'Confirm fixed',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppStatusColors.resolvedText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isCurrent,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isCurrent
        ? AppTheme.primaryGreen
        : (isCompleted ? AppStatusColors.resolvedText : AppTheme.borderLight);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Node and connecting line
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent
                        ? dotColor
                        : AppTheme.offWhiteBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dotColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : (isCurrent
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted
                          ? AppStatusColors.resolvedText
                          : AppTheme.borderLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Right Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.w600,
                      color: isCompleted || isCurrent
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
