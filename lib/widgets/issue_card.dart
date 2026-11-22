import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/issue_model.dart';
import 'status_chip.dart';

/// Reusable card displaying an Issue preview with thumbnail, metadata, status chip,
/// and optional 'Me too' counter button.
class IssueCard extends StatelessWidget {
  final Issue issue;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback? onMeTooTap;
  final bool showMeTooButton;

  const IssueCard({
    super.key,
    required this.issue,
    required this.currentUserId,
    required this.onTap,
    this.onMeTooTap,
    this.showMeTooButton = false,
  });

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUserMeToo = issue.hasMeToo(currentUserId);
    final isUnresolved = issue.status != IssueStatus.resolved;
    final isFromOtherUser = issue.reportedBy != currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Thumbnail Image or Category Icon Fallback
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
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppTheme.textSecondary,
                                  size: 28,
                                ),
                              ),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              },
                            )
                          : const Center(
                              child: Icon(
                                Icons.report_problem_outlined,
                                color: AppTheme.primaryGreen,
                                size: 30,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 2. Title, Area, and Time
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
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                issue.area,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '•',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTimeAgo(issue.createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Bottom Row: Status Chip & Optional 'Me too' button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusChip(status: issue.status),

                  // 'Me too' Button for unresolved issues from other people on "All campus"
                  if (showMeTooButton && isUnresolved && isFromOtherUser)
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppTheme.minTouchTargetSize,
                        minWidth: 44,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: onMeTooTap,
                        icon: Icon(
                          hasUserMeToo
                              ? Icons.thumb_up_alt_rounded
                              : Icons.thumb_up_alt_outlined,
                          size: 15,
                          color: hasUserMeToo
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                        ),
                        label: Text(
                          hasUserMeToo
                              ? 'Me too (${issue.meTooCount})'
                              : 'Me too${issue.meTooCount > 0 ? " (${issue.meTooCount})" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: hasUserMeToo
                                ? AppTheme.primaryGreen
                                : AppTheme.textPrimary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          backgroundColor: hasUserMeToo
                              ? AppTheme.primaryGreen.withOpacity(0.08)
                              : Colors.transparent,
                          side: BorderSide(
                            color: hasUserMeToo
                                ? AppTheme.primaryGreen
                                : AppTheme.borderLight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    )
                  else if (issue.meTooCount > 0)
                    // Simply show count if not clickable here
                    Row(
                      children: [
                        const Icon(
                          Icons.group_outlined,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${issue.meTooCount} affected',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
